package app

import cats.effect.ExitCode
import cats.effect.IO
import cats.effect.IOApp
import com.anthropic.mcp.CallToolResult
import com.anthropic.mcp.ClientCapabilities
import com.anthropic.mcp.ContentBlock
import com.anthropic.mcp.Cursor
import com.anthropic.mcp.Implementation
import com.anthropic.mcp.InitializeResult
import com.anthropic.mcp.ListToolsResult
import com.anthropic.mcp.ServerCapabilities
import com.anthropic.mcp.TaskMetadata
import com.anthropic.mcp.TextContent
import com.anthropic.mcp.Tool
import com.anthropic.mcp.ToolSchema
import com.anthropic.mcp.ToolsCapability
import com.github.plokhotnyuk.jsoniter_scala.circe.JsoniterScalaCodec._
import com.github.plokhotnyuk.jsoniter_scala.core._
import fs2.Stream
import fs2.io.file.Files
import io.circe.Decoder
import io.circe.Encoder
import io.circe.HCursor
import io.circe.Json
import jsonrpclib.CallId
import jsonrpclib.Message
import jsonrpclib.Payload
import jsonrpclib.ProtocolError
import jsonrpclib.fs2.CancelTemplate
import jsonrpclib.fs2.FS2Channel
import jsonrpclib.fs2.given
import jsonrpclib.fs2.lsp
import jsonrpclib.smithy4sinterop.ServerEndpoints
import my.server.AdderInput
import my.server.AdderOutput
import my.server.MyMcpServer
import smithy4s.Document
import smithy4s.Hints
import smithy4s.ShapeId
import smithy4s.schema.Field
import smithy4s.schema.Primitive
import smithy4s.schema.Schema
import smithy4s.schema.SchemaVisitor

object main extends IOApp.Simple {

  // Reserving a method for cancelation.
  val cancelEndpoint = CancelTemplate.make[CallId]("notifications/cancelled", identity, identity)

  def printErr(s: String): IO[Unit] = IO.consoleForIO.errorln(s)
  // *> Files[IO]
  //   .writeAll(fs2.io.file.Path("debug.log"))
  //   .apply(fs2.Stream.emit(s + "\n").through(fs2.text.utf8.encode))
  //   .compile
  //   .drain

  enum SSchema {
    case ObjectSchema(properties: Map[String, SSchema], required: List[String])
    case NumberSchema

    def asDocument: Document =
      this match {
        case ObjectSchema(properties, required) =>
          Document.obj(
            "type" -> Document.fromString("object"),
            "properties" -> Document.obj(
              properties.map(_ -> _.asDocument).toSeq
            ),
            "required" -> Document.array(required.map(Document.fromString)),
          )
        case NumberSchema => Document.obj("type" -> Document.fromString("number"))
      }

  }

  object SchemaDerivation extends SchemaVisitor.Default[[_] =>> SSchema] {
    def default[A]: SSchema = ???

    override def primitive[P](shapeId: ShapeId, hints: Hints, tag: Primitive[P]): SSchema =
      tag match {
        case Primitive.PInt => SSchema.NumberSchema
        case _              => ???
      }

    override def option[A](schema: Schema[A]): SSchema = schema.compile(
      this
    ) // optionality handled on struct level

    override def struct[S](
      shapeId: ShapeId,
      hints: Hints,
      fields: Vector[Field[S, ?]],
      make: IndexedSeq[Any] => S,
    ): SSchema = SSchema.ObjectSchema(
      properties = fields.map(f => f.label -> f.schema.compile(this)).toMap,
      required = fields.filter(_.isRequired).map(_.label).toList,
    )

  }

  def deriveSchema[A: Schema]: ToolSchema =
    Schema[A].compile(SchemaDerivation) match {
      case SSchema.ObjectSchema(properties, required) =>
        ToolSchema(
          _type = "object",
          properties = Some(Document.obj(properties.map(_ -> _.asDocument).toSeq)),
          required = Some(required),
        )
      case _ => sys.error("Only object schemas are supported on the top level")
    }

  def run: IO[Unit] = {

    val caps = ServerCapabilities(
      tools = Some(
        ToolsCapability(
        )
      )
    )

    val srv: MyMcpServer[IO] =
      new {
        def initialize(
          protocolVersion: String,
          capabilities: ClientCapabilities,
          clientInfo: Implementation,
          _meta: Option[Map[String, Document]],
        ): IO[InitializeResult] =
          printErr("initialize called") *>
            IO.pure(
              InitializeResult(
                protocolVersion = "2025-11-25",
                capabilities = caps,
                serverInfo = Implementation(
                  name = "mcp-notes-server",
                  version = "0.0.0",
                ),
              )
            )

        def listTools(cursor: Option[Cursor], _meta: Option[Map[String, Document]])
          : IO[ListToolsResult] =
          printErr("listTools called") *> IO.pure(
            ListToolsResult(
              tools = List(
                Tool(
                  name = "adder",
                  inputSchema = deriveSchema[AdderInput],
                  outputSchema = Some(deriveSchema[AdderOutput]),
                )
              )
            )
          )

        def callTool(
          name: String,
          arguments: Option[Document],
          task: Option[TaskMetadata],
          _meta: Option[Map[String, Document]],
        ): IO[CallToolResult] =
          printErr(s"callTool called with name: $name and arguments: $arguments") *> {
            val decodedArgs = Document.decode[AdderInput](arguments.get).toTry.get

            IO.pure(
              CallToolResult(
                content = Nil,
                structuredContent = Some(
                  Document.obj(
                    "result" -> Document.fromInt(decodedArgs.a + decodedArgs.b.getOrElse(0))
                  )
                ),
              )
            )
          }
      }

    val decode: fs2.Pipe[IO, Byte, Either[ProtocolError, Message]] =
      _.through(fs2.text.utf8.decode[IO])
        .through(fs2.text.lines[IO])
        .map { line =>
          Payload(readFromArray[Json](line.getBytes()))
        }
        .map { payload =>
          Decoder[Message]
            .apply(HCursor.fromJson(payload.data))
            .left
            .map(e => ProtocolError.ParseError(e.getMessage))
        }

    val encode: fs2.Pipe[IO, Message, Byte] =
      _.map(Encoder[Message].apply(_).noSpaces + "\n").through(fs2.text.utf8.encode[IO])

    val go = FS2Channel
      .stream[IO](cancelTemplate = Some(cancelEndpoint))
      .flatMap { channel =>
        // Stream.eval(IO.fromEither(ClientStub(TestClient, channel))).flatMap { testClient =>
        Stream.eval(IO.fromEither(ServerEndpoints(srv))).flatMap { se =>
          channel.withEndpointsStream(se)
        }
        // }
      }
      .flatMap { channel =>
        fs2
          .Stream
          .eval(IO.never) // running the server forever
          .concurrently(
            fs2
              .io
              .stdin[IO](512)
              // .observe(_.through(Files[IO].writeAll(fs2.io.file.Path("input.log"))))
              // .through(lsp.decodeMessages)
              .through {
                _.through(fs2.text.utf8.decode[IO])
                  .through(fs2.text.lines[IO])
                  .map { line =>
                    Payload(readFromArray[Json](line.getBytes()))
                  }
                  .map { payload =>
                    Decoder[Message]
                      .apply(HCursor.fromJson(payload.data))
                      .left
                      .map(e => ProtocolError.ParseError(e.getMessage))
                  }

              }
              // .observe(
              // _.map(_.toString).through(Files[IO].writeUtf8(fs2.io.file.Path("decoded.log")))
              // )
              .through(channel.inputOrBounce)
          )
          .concurrently(
            channel
              .output
              .through(encode)
              // .observe(_.through(Files[IO].writeAll(fs2.io.file.Path("output.log"))))
              .through(fs2.io.stdout[IO])
          )
      }

    // Using errorln as stdout is used by the RPC channel
    printErr("Starting server") >> go.compile.drain.guarantee(printErr("Terminating server"))
  }

}
