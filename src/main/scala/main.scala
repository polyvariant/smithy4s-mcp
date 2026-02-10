package app

import cats.effect.IO
import cats.effect.IOApp
import com.anthropic.mcp.ClientCapabilities
import com.anthropic.mcp.Implementation
import com.anthropic.mcp.InitializeResult
import com.anthropic.mcp.ServerCapabilities
import com.anthropic.mcp.ToolsCapability
import my.server.AdderOutput
import my.server.MyMcpServer
import my.server.MyServer
import smithy4s.Document
import smithy4smcp.*

object main extends IOApp.Simple {

  def run: IO[Unit] = {

    val myTools: MyServer[IO] =
      new {
        def adder(a: Int, b: Option[Int]): IO[AdderOutput] = IO.pure(
          AdderOutput(result = a + b.getOrElse(0))
        )
      }

    printErr("Starting server") *>
      start(customize(srv(myTools)))
        .compile
        .drain
        .guarantee(printErr("Terminating server"))
  }

  def customize(
    server: MyMcpServer[IO]
  ): MyMcpServer[IO] =
    new MyMcpServer[IO] {
      export server.{initialize as _, *}

      def initialize(
        protocolVersion: String,
        capabilities: ClientCapabilities,
        clientInfo: Implementation,
        _meta: Option[Map[String, Document]],
      ): IO[InitializeResult] = IO.pure(
        InitializeResult(
          protocolVersion = "2025-11-25",
          capabilities = ServerCapabilities(
            tools = Some(ToolsCapability())
          ),
          serverInfo = Implementation(
            name = "my-mcp-server",
            version = "0.0.0",
          ),
        )
      )
    }

}
