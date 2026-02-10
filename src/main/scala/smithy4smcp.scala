package app

import cats.effect.IO
import cats.effect.Resource
import cats.syntax.all.*
import com.github.plokhotnyuk.jsoniter_scala.circe.JsoniterScalaCodec.*
import com.github.plokhotnyuk.jsoniter_scala.core.*
import io.circe.Decoder
import io.circe.Encoder
import io.circe.HCursor
import io.circe.Json
import jsonrpclib.CallId
import jsonrpclib.JsonRpcPayload
import jsonrpclib.Message
import jsonrpclib.Payload
import jsonrpclib.ProtocolError
import jsonrpclib.fs2.CancelTemplate
import jsonrpclib.fs2.FS2Channel
import jsonrpclib.fs2.given
import jsonrpclib.smithy4sinterop.ClientStub
import jsonrpclib.smithy4sinterop.ServerEndpoints
import modelcontextprotocol.CallToolResult
import modelcontextprotocol.ClientCapabilities
import modelcontextprotocol.ContentBlock
import modelcontextprotocol.ContentBlock.TextCase
import modelcontextprotocol.Cursor
import modelcontextprotocol.ElicitFormSchema
import modelcontextprotocol.ElicitRequestFormParams
import modelcontextprotocol.ElicitRequestParams
import modelcontextprotocol.Implementation
import modelcontextprotocol.InitializeResult
import modelcontextprotocol.ListToolsResult
import modelcontextprotocol.ServerCapabilities
import modelcontextprotocol.TaskMetadata
import modelcontextprotocol.Tool
import modelcontextprotocol.ToolAnnotations
import modelcontextprotocol.ToolSchema
import modelcontextprotocol.ToolsCapability
import smithy.api.Readonly
import smithy4s.Bijection
import smithy4s.Document
import smithy4s.Endpoint
import smithy4s.Hints
import smithy4s.Service
import smithy4s.ShapeId
import smithy4s.kinds.FunctorAlgebra
import smithy4s.schema.Alt
import smithy4s.schema.Alt.Dispatcher
import smithy4s.schema.CollectionTag
import smithy4s.schema.EnumTag
import smithy4s.schema.EnumTag.ClosedIntEnum
import smithy4s.schema.EnumTag.ClosedStringEnum
import smithy4s.schema.EnumValue
import smithy4s.schema.Field
import smithy4s.schema.Primitive
import smithy4s.schema.Schema
import smithy4s.schema.Schema.StructSchema
import smithy4s.schema.Schema.UnionSchema
import smithy4s.schema.SchemaVisitor
import smithy4s.~>
import smithy4smcptraits.McpClientApi
import smithy4smcptraits.McpServerApi
import smithy4smcptraits.McpTool
import util.chaining.*

import scala.collection.immutable.ListMap

import McpBuilder.internal.*

object McpBuilder {

  def server[Alg[_[_, _, _, _, _]]](
    impl: FunctorAlgebra[Alg, IO]
  )(
    using service: Service[Alg]
  ): McpServerApi[IO] =
    new {
      def ping(): IO[Unit] = IO.unit

      val allMyMonkeysCompiled: ListMap[String, CompiledTool] = {
        val fk = service.toPolyFunction(impl)

        service
          .endpoints
          .filter(_.hints.has[McpTool])
          .map { e =>
            val toolHint = e
              .hints
              .get[McpTool]
              .getOrElse(
                sys.error(s"Endpoint ${e.id} is not a tool, we can't compile it")
              )

            val decodeIn = Document.Decoder.fromSchema(e.input)
            val encodeOut = Document.Encoder.fromSchema(e.output)

            CompiledTool(
              Tool(
                name = toolName(toolHint, e),
                inputSchema = deriveSchema(
                  using e.input
                ),
                outputSchema = Some(
                  deriveSchema(
                    using e.output
                  )
                ),
                annotations = Some(
                  ToolAnnotations(
                    readOnlyHint = Some(e.hints.has[Readonly]),
                    idempotentHint = Some(e.hints.has[smithy.api.Idempotent]),
                  )
                ),
              ),
              impl =
                _.pipe(decodeIn.decode)
                  .liftTo[IO]
                  .map(e.wrap)
                  .flatMap(fk(_))
                  .map(encodeOut.encode),
            )
          }
          .map(ct => ct.tool.name -> ct)
          .to(ListMap)
      }

      def initialize(
        protocolVersion: String,
        capabilities: ClientCapabilities,
        clientInfo: Implementation,
        _meta: Option[Map[String, Document]],
      ): IO[InitializeResult] =
        printErr("default initialize called") *>
          IO.pure(
            InitializeResult(
              protocolVersion = "2025-11-25",
              capabilities = ServerCapabilities(
                tools = Some(ToolsCapability())
              ),
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
            tools = allMyMonkeysCompiled.values.map(_.tool).toList
          )
        )

      def callTool(
        name: String,
        arguments: Option[Document],
        task: Option[TaskMetadata],
        _meta: Option[Map[String, Document]],
      ): IO[CallToolResult] =
        printErr(s"callTool called with name: $name and arguments: $arguments") *>
          allMyMonkeysCompiled
            .get(name)
            .liftTo[IO](new Exception(s"Tool $name not found"))
            .flatMap { ct =>
              val argsDoc = arguments.getOrElse(Document.obj())

              ct.impl(argsDoc).map { outDoc =>
                CallToolResult(
                  content = Nil,
                  structuredContent = Some(outDoc),
                )
              }
            }
    }

  object internal {

    case class CompiledTool(
      tool: Tool,
      impl: Document => IO[Document],
    )

    enum JsonSchema {
      case ObjectSchema(properties: Map[String, JsonSchema], required: List[String])
      case AnyOfSchema(options: List[JsonSchema])
      case NumberSchema
      case StringSchema
      case ListSchema(itemSchema: JsonSchema)
      case EnumSchema(options: List[String])
      case IntEnumSchema(options: List[Int])

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
          case NumberSchema         => Document.obj("type" -> Document.fromString("number"))
          case StringSchema         => Document.obj("type" -> Document.fromString("string"))
          case AnyOfSchema(options) =>
            Document.obj(
              "anyOf" -> Document.array(options.map(_.asDocument))
            )
          case ListSchema(itemSchema) =>
            Document.obj(
              "type" -> Document.fromString("array"),
              "items" -> itemSchema.asDocument,
            )
          case EnumSchema(options) =>
            Document.obj(
              "type" -> Document.fromString("string"),
              "enum" -> Document.array(options.map(Document.fromString)),
            )
          case IntEnumSchema(options) =>
            Document.obj(
              "type" -> Document.fromString("integer"),
              "enum" -> Document.array(options.map(Document.fromInt)),
            )
        }

    }

    object SchemaDerivation extends SchemaVisitor.Default[[_] =>> JsonSchema] {
      def default[A]: JsonSchema = ???

      override def union[U](
        shapeId: ShapeId,
        hints: Hints,
        alternatives: Vector[Alt[U, ?]],
        dispatch: Dispatcher[U],
      ): JsonSchema = JsonSchema.AnyOfSchema(
        alternatives.toList.map(alt => alt.schema.compile(this))
      )

      override def primitive[P](shapeId: ShapeId, hints: Hints, tag: Primitive[P]): JsonSchema =
        tag match {
          case Primitive.PInt    => JsonSchema.NumberSchema
          case Primitive.PString => JsonSchema.StringSchema
          case _                 => ???
        }

      override def enumeration[E](
        shapeId: ShapeId,
        hints: Hints,
        tag: EnumTag[E],
        values: List[EnumValue[E]],
        total: E => EnumValue[E],
      ): JsonSchema =
        tag match {
          case ClosedIntEnum    => JsonSchema.IntEnumSchema(values.map(_.intValue))
          case ClosedStringEnum => JsonSchema.EnumSchema(values.map(_.stringValue))
          case _                => sys.error("Open enums are not supported")
        }

      override def biject[A, B](schema: Schema[A], bijection: Bijection[A, B]): JsonSchema = schema
        .compile(
          this
        ) // just compile the underlying schema, the bijection doesn't change the JSON schema

      override def option[A](schema: Schema[A]): JsonSchema = schema.compile(
        this
      ) // optionality handled on struct level

      override def collection[C[_], A](
        shapeId: ShapeId,
        hints: Hints,
        tag: CollectionTag[C],
        member: Schema[A],
      ): JsonSchema = JsonSchema.ListSchema(member.compile(this))

      override def struct[S](
        shapeId: ShapeId,
        hints: Hints,
        fields: Vector[Field[S, ?]],
        make: IndexedSeq[Any] => S,
      ): JsonSchema = JsonSchema.ObjectSchema(
        properties = fields.map(f => f.label -> f.schema.compile(this)).toMap,
        required = fields.filter(_.isRequired).map(_.label).toList,
      )

    }

    def deriveSchema[A: Schema]: ToolSchema =
      Schema[A].compile(SchemaDerivation) match {
        case JsonSchema.ObjectSchema(properties, required) =>
          ToolSchema(
            _type = "object",
            properties = Some(Document.obj(properties.map(_ -> _.asDocument).toSeq)),
            required = Some(required),
          )
        case _ => sys.error("Only object schemas are supported on the top level")
      }

  }

  def remoteServerStub[Alg[_[_, _, _, _, _]]](
    service: Service[Alg]
  )(
    using rawServer: McpServerApi[IO]
  ): service.Impl[IO] = service.impl {
    new service.FunctorEndpointCompiler[IO] {
      def apply[I, E, O, SI, SO](e: service.Endpoint[I, E, O, SI, SO]): I => IO[O] = {
        val toolHint = e
          .hints
          .get[McpTool]
          .getOrElse(
            sys.error(
              s"Endpoint ${e.id} is not a tool, we can't derive a client for it"
            )
          )

        val inputEncoder = Document.Encoder.fromSchema(e.input)
        val resultDecoder = Document.Decoder.fromSchema(JsonPayloadTransformation(e.output))

        i =>
          rawServer
            .callTool(name = toolName(toolHint, e), arguments = inputEncoder.encode(i).some)
            .flatMap {
              case CallToolResult(structuredContent = Some(content)) =>
                content
                  .decode(
                    using resultDecoder
                  )
                  .liftTo[IO]

              // Best-effort JSON decoding from unstructured content.
              // The github MCP doesn't use structured responses, for example, so we shouldn't be typing them
              // but I figured for the example's sake there's no reason not to at least try.
              case CallToolResult(content = content) =>

                val docs = content
                  .map {
                    case TextCase(text) => text.text
                    case other          =>
                      sys.error(
                        s"Only text content blocks are supported in this context. Got ${ContentBlock.schema.asInstanceOf[UnionSchema[?]].alternatives(other.$ordinal).label}."
                      )
                  }
                  .map { text =>
                    smithy4s.json.Json.readDocument(text).getOrElse(Document.fromString(text))
                  }

                docs match {
                  case one :: Nil => resultDecoder.decode(one).liftTo[IO]
                  case _          => resultDecoder.decode(Document.array(docs)).liftTo[IO]
                }

            }
      }
    }
  }

  // TODO: publish this from jsonrpclib
  private object JsonPayloadTransformation extends (Schema ~> Schema) {

    def apply[A0](fa: Schema[A0]): Schema[A0] =
      fa match {
        case struct: StructSchema[b] =>
          struct
            .fields
            .collectFirst {
              case field if field.hints.has[JsonRpcPayload] =>
                field.schema.biject[b]((f: Any) => struct.make(Vector(f)))(field.get)
            }
            .getOrElse(fa)
        case _ => fa
      }

  }

  private def toolName[Op[_, _, _, _, _]](toolHint: McpTool, e: Endpoint[Op, ?, ?, ?, ?, ?])
    : String = toolHint.name.getOrElse(e.id.name)

  def clientStub[Alg[_[_, _, _, _, _]]](
    service: Service[Alg]
  )(
    using rawClient: McpClientApi[IO]
  ): service.Impl[IO] = service.impl {
    new service.FunctorEndpointCompiler[IO] {
      def apply[I, E, O, SI, SO](fa: service.Endpoint[I, E, O, SI, SO]): I => IO[O] = {

        val messageFinder: Option[I => String] =
          fa.input match {
            case StructSchema(shapeId, hints, fields, make) =>
              fields.find(_.label == "message").map { field =>
                val toDoc = Document.Encoder.fromSchema(field.schema)
                field
                  .get
                  .andThen { a =>
                    toDoc.encode(a) match {
                      case Document.DString(s) => s
                      case _ => sys.error("Expected the 'message' field to be a string")
                    }
                  }
              }

            case _ => None
          }

        val inputToMessage = messageFinder.getOrElse(
          Function.const(s"Server is asking (${fa.id.name})")
        )

        val requestedSchema = {
          val compiled = deriveSchema(
            using fa.output
          )
          ElicitFormSchema(
            _type = "object",
            properties = compiled.properties.get,
            required = compiled.required,
          )
        }

        val resultDecoder = Document.Decoder.fromSchema(fa.output)

        { i =>
          rawClient
            .elicitation(
              ElicitRequestParams.form(
                form = ElicitRequestFormParams(
                  message = inputToMessage(i),
                  requestedSchema = requestedSchema,
                )
              )
            )
            .flatMap(
              _.content
                .get
                .decode(
                  using resultDecoder
                )
                .liftTo[IO]
            )
        }
      }
    }
  }

}

object interop {

  def startServer(srv: McpClientApi[IO] ?=> McpServerApi[IO]): Resource[IO, McpClientApi[IO]] =
    startGen(srv, fs2.io.stdin[IO](512), fs2.io.stdout[IO])

  def startClient(c: McpServerApi[IO] ?=> McpClientApi[IO], process: fs2.io.process.Process[IO])
    : Resource[IO, McpServerApi[IO]] = startGen(c, process.stdout, process.stdin)

  def startGen[Local[_[_, _, _, _, _]], Remote[_[_, _, _, _, _]]](
    srv: FunctorAlgebra[Remote, IO] ?=> FunctorAlgebra[Local, IO],
    input: fs2.Stream[IO, Byte],
    output: fs2.Pipe[IO, Byte, Nothing],
  )(
    using Local: Service[Local],
    Remote: Service[Remote],
  ): Resource[IO, Remote.Impl[IO]] = FS2Channel
    .resource[IO](cancelTemplate = Some(cancelEndpoint))
    .flatMap { channel =>
      ClientStub(Remote, channel).liftTo[IO].toResource.flatMap { client =>
        ServerEndpoints(
          srv(
            using client
          )
        ).liftTo[IO]
          .toResource
          .flatMap { se =>
            channel.withEndpoints(se)
          }
          .flatMap { channel =>
            input
              // .observe(_.through(Files[IO].writeAll(fs2.io.file.Path("input.log"))))
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
              .compile
              .drain
              .background &> (
              channel
                .output
                .through(encode)
                // .observe(_.through(Files[IO].writeAll(fs2.io.file.Path("output.log"))))
                .through(output)
                .compile
                .drain
                .background
                .as(client)
            )
          }
      }
    }

  // Reserving a method for cancelation.
  val cancelEndpoint = CancelTemplate.make[CallId]("notifications/cancelled", identity, identity)

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

}

def printErr(s: String): IO[Unit] = IO.consoleForIO.errorln(s)

// *> Files[IO]
//   .writeAll(fs2.io.file.Path("debug.log"))
//   .apply(fs2.Stream.emit(s + "\n").through(fs2.text.utf8.encode))
//   .compile
//   .drain
