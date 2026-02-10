package app

import cats.effect.IO
import cats.effect.IOApp
import modelcontextprotocol.ClientCapabilities
import modelcontextprotocol.Implementation
import modelcontextprotocol.InitializeResult
import my.server.AdderOutput
import my.server.AskNameOutput
import my.server.Character
import my.server.CharacterType
import my.server.ListCharactersOutput
import my.server.MyClient
import my.server.MyServer
import my.server.Name
import smithy4s.Document

object main extends IOApp.Simple {

  def run: IO[Unit] = {

    def myTools(
      getClientCapabilities: IO[ClientCapabilities]
    )(
      using client: MyClient[IO]
    ): MyServer[IO] =
      new {
        def adder(a: Int, b: Option[Int]): IO[AdderOutput] =
          for {
            clientCaps <- getClientCapabilities
            _ <- printErr(s"Caps: $clientCaps")
            name <-
              if clientCaps.elicitation.isDefined
              then client.askName("say my name")
              else
                IO.pure(AskNameOutput("default"))
            _ <- printErr(s"Hello, $name! Adding $a and ${b.getOrElse(0)}")
          } yield AdderOutput(
            result = a + b.getOrElse(0),
            Some(s"You're goddamn right, ${name.name}"),
          )

        def listCharacters(): IO[ListCharactersOutput] =

          IO.pure {
            ListCharactersOutput {
              List("walter", "mike")
                .map(
                  Name(_)
                )
                .map(Character(_, CharacterType.BAD))
            }
          }
      }

    printErr("Starting server") *>
      IO.ref(Option.empty[ClientCapabilities]).flatMap { clientCaps =>
        interop
          .startServer {
            val impl = McpBuilder.server(
              myTools(clientCaps.get.map(_.getOrElse(ClientCapabilities())))(
                using McpBuilder.clientStub(MyClient)
              )
            )

            new {
              export impl.{initialize as _, *}

              def initialize(
                protocolVersion: String,
                capabilities: ClientCapabilities,
                clientInfo: Implementation,
                _meta: Option[Map[String, Document]],
              ): IO[InitializeResult] =
                impl.initialize(
                  protocolVersion,
                  capabilities,
                  clientInfo,
                  _meta,
                ) <* clientCaps.set(Some(capabilities))
            }
          }
          .onFinalize(printErr("Terminating server"))
          .useForever
      }
  }

}
