package app

import cats.effect.IO
import cats.effect.IOApp
import modelcontextprotocol.ClientCapabilities
import modelcontextprotocol.Implementation
import modelcontextprotocol.InitializeResult
import modelcontextprotocol.ServerCapabilities
import modelcontextprotocol.ToolsCapability
import my.server.AdderOutput
import my.server.MyServer
import smithy4s.Document
import smithy4smcptraits.McpServerApi

object main extends IOApp.Simple {

  def run: IO[Unit] = {

    val myTools: MyServer[IO] =
      new {
        def adder(a: Int, b: Option[Int]): IO[AdderOutput] = IO.pure(
          AdderOutput(result = a + b.getOrElse(0))
        )
      }

    printErr("Starting server") *>
      interop
        .start(customize(McpServerBuilder.build(myTools)))
        .compile
        .drain
        .guarantee(printErr("Terminating server"))
  }

  def customize(
    server: McpServerApi[IO]
  ): McpServerApi[IO] =
    new McpServerApi[IO] {
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
