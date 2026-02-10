package app

import cats.effect.ExitCode
import cats.effect.IO
import cats.effect.IOApp
import fs2.io.process.Processes
import modelcontextprotocol.ClientCapabilities
import modelcontextprotocol.Implementation
import smithy4smcptraits.McpClientApi

object clientMain extends IOApp {

  def run(args: List[String]): IO[ExitCode] =

    printErr("Starting client") *>
      Processes[IO]
        .spawn(fs2.io.process.ProcessBuilder(args.head, args.tail))
        .flatMap { proc =>
          interop
            .startClient(
              new McpClientApi.Default[IO](IO.stub),
              proc,
            )
        }
        .onFinalize(printErr("Terminating client"))
        .use { remote =>
          remote
            .initialize(
              protocolVersion = "2025-11-25",
              capabilities = ClientCapabilities(),
              clientInfo = Implementation(name = "smithy4s-mcp-client", "0.0.0"),
            )
            .flatMap { result =>
              printErr(
                s"Connected to server: ${result.serverInfo.name} ${result.serverInfo.version}\n"
              )
            } *>
            remote
              .listTools()
              .flatMap { result =>
                printErr(s"Available tools: ${result.tools.map(_.name).mkString("\n", "\n", "")}")
              }
        }
        .as(ExitCode.Success)

}
