package app

import cats.effect.IO
import cats.effect.IOApp
import my.server.AdderOutput
import my.server.MyClient
import my.server.MyServer

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
      }

    printErr("Starting server") *>
      interop
        .start(
          McpBuilder.server(
            myTools(
              using McpBuilder.client(MyClient)
            )
          )
        )
        .compile
        .drain
        .guarantee(printErr("Terminating server"))
  }

}
