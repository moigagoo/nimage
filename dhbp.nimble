# Package

version       = "1.0.5"
author        = "Constantine Molchanov"
description   = "App to build Nim Docker images and push them to Docker Hub."
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["dhbp"]


# Dependencies

requires "nim >= 2.2.2"
requires "climate >= 1.1.3"

