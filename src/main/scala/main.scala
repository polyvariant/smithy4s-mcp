package app

import cats.effect.IO
import cats.effect.IOApp
import my.server.AdderOutput
import my.server.Character
import my.server.CharacterType
import my.server.ListCharactersOutput
import my.server.MyClient
import my.server.MyServer
import my.server.Name

object main extends IOApp.Simple {

  def run: IO[Unit] = {

    def myTools(
      using client: MyClient[IO]
    ): MyServer[IO] =
      new {
        def adder(a: Int, b: Option[Int]): IO[AdderOutput] =
          for {
            name <- client.askName("say my name")
            _ <- printErr(s"Hello, $name! Adding $a and ${b.getOrElse(0)}")
          } yield AdderOutput(
            result = a + b.getOrElse(0),
            Some(s"You're goddamn right, ${name.name}"),
          )

        def listCharacters(): IO[ListCharactersOutput] =

          IO.pure {
            ListCharactersOutput {
              List("waltuh", "kid named finger")
                .map(
                  Name(_)
                )
                .map(Character(_, CharacterType.BAD))
            }
          }
      }

    printErr("Starting server") *>
      interop
        .startServer(
          McpBuilder.server(
            myTools(
              using McpBuilder.clientStub(MyClient)
            )
          )
        )
        .onFinalize(printErr("Terminating server"))
        .useForever
  }

}
