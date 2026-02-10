ThisBuild / scalaVersion := "3.8.1"

lazy val models = project
  .in(file("models"))
  .enablePlugins(Smithy4sCodegenPlugin)
  .settings(
    name := "models",
    libraryDependencies ++= Seq(
      "com.disneystreaming.smithy4s" %% "smithy4s-core" % smithy4sVersion.value,
      "tech.neander" % "jsonrpclib-smithy" % "0.1.0" % Smithy4s,
    ),
  )

lazy val root = project
  .in(file("."))
  .aggregate(models)
  .dependsOn(models)
  .settings(
    name := "mcp-notes",
    libraryDependencies ++= Seq(
      "tech.neander" %% "jsonrpclib-fs2" % "0.1.0",
      "tech.neander" %% "jsonrpclib-smithy4s" % "0.1.0",
      "co.fs2" %% "fs2-io" % "3.12.2",
      "org.typelevel" %% "cats-effect" % "3.6.3",
    ),
    run / fork := true,
    scalacOptions ++= Seq(
      "-Wunused:all"
    ),
  )
  .enablePlugins(JavaAppPackaging)
