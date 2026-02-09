package app

import cats.effect.IO
import cats.effect.IOApp
import my.server.AdderOutput
import my.server.MyServer
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
      start(srv(myTools))
        .compile
        .drain
        .guarantee(printErr("Terminating server"))
  }

}
