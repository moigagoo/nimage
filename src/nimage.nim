import std/[os, strutils, json]

import climate

import nimage/flavors/[slim, regular]


proc isDefault(props: JsonNode): bool =
  props.getOrDefault("default").getBool

proc isLatest(props: JsonNode): bool =
  props.getOrDefault("latest").getBool

proc getTags(
    version, base: tuple[key: string, val: JsonNode], flavor: string
): seq[string] =
  result = @[]

  result.add([version.key, base.key, flavor].join("-"))

  if flavor == "regular":
    result.add([version.key, base.key].join("-"))

    if version.val.isLatest:
      result.add(["latest", base.key].join("-"))

    if base.val.isDefault:
      result.add version.key

  if version.val.isLatest:
    result.add(["latest", base.key, flavor].join("-"))

    if flavor == "regular":
      result.add base.key

  if base.val.isDefault:
    result.add([version.key, flavor].join("-"))

  if version.val.isLatest and base.val.isDefault:
    if flavor == "regular":
      result.add "latest"

    result.add(["latest", flavor].join("-"))
    result.add flavor

proc generateDockerfile(
    version, base, flavor: string,
    labels: openarray[(string, string)],
    dockerfileDir: string,
) =
  var content = ""

  case flavor
  of "slim":
    case base
    of "ubuntu":
      content = slim.ubuntu(version, labels)
    of "alpine":
      content = slim.alpine(version, labels)
    else:
      discard
  of "regular":
    case base
    of "ubuntu":
      content = regular.ubuntu(version, labels)
    of "alpine":
      content = regular.alpine(version, labels)
    else:
      discard
  else:
    discard

  createDir(dockerfileDir)

  writeFile(dockerfileDir / "Dockerfile", content)

proc buildAndPushImage(
    tags: openarray[string], tagPrefix: string, dockerfileDir: string
) =
  const dockerBuildCommand =
    "docker buildx build --push --platform linux/amd64,linux/arm64,linux/arm $# $#"

  var tagLine = ""

  for tag in tags:
    tagLine &= " -t $#:$# " % [tagPrefix, tag]

  discard execShellCmd dockerBuildCommand % [tagLine, dockerfileDir]

proc testImage(image: string, flavor: string) =
  let succeeded =
    case flavor
    of "slim":
      let cmd = "docker run --rm $# nim --version" % image
      execShellCmd(cmd) == 0
    of "regular":
      # Check that nimble at least launches
      let cmd = "docker run --rm $# nimble --version" % image
      execShellCmd(cmd) == 0
    else:
      true

  if not succeeded:
    echo "Failed the image test"

proc showHelp(context: Context): int =
  const helpMessage =
    """Before running the app for the first time, create a multiarch builder:

  $ nimage setup

Usage:

  $ nimage build-and-push [--config|-c=config.json] [--all|-a] [--dry|-d] [--save|-s] [<version> <version> ...]

Build and push specific versions:

  $ nimage build-and-push <version1> <version2> ...

Build and push specific versions and save the Dockerfiles in `Dockerfiles/<version>/<flavor>`:

  $ nimage build-and-push --save <version1> <version2> ...

Build and push all versions listed in the config file:

  $ nimage build-and-push --all
  
Use custom config file (by default, `config.json` in the current directory is used):

  $ nimage build-and-push --config=path/to/custom_config.json <version1> <version2> ...

Dry run (nothing is built or pushed, use to check the config and command args):

  $ nimage build-and-push --dry <version1> <version2> ...
"""

  echo helpMessage

proc createBuilder(context: Context): int =
  const createDockerBuilderCommand =
    "docker buildx create --use --platform=linux/arm64,linux/amd64 --name multi-platform-builder"
  discard execShellCmd createDockerBuilderCommand

proc buildAndPushImages(context: Context): int =
  const
    labels = {"authors": "https://github.com/nim-lang/docker-images/graphs/contributors"}
    tagPrefix = "nimlang/nim"
    flavors = ["slim", "regular"]
    dockerfilesDir = "Dockerfiles"

  var
    configFile = "config.json"
    buildAll = false
    buildLatest = false
    dryRun = false
    save = false
    targets: seq[string] = @[]

  context.opt("config", "c"):
    configFile = val

  context.flag("all", "a"):
    buildAll = true

  context.flag("latest", "l"):
    buildLatest = true

  context.flag("dry", "d"):
    dryRun = true

  context.flag("save", "s"):
    save = true

  context.args:
    targets = args

  let
    config = parseFile(configFile)
    bases = config["bases"]
    versions = config["versions"]

  for version in versions.pairs:
    if buildAll or version.key in targets or (buildLatest and version.val.isLatest):
      for base in bases.pairs:
        for flavor in flavors:
          let
            dockerfileDir = dockerfilesDir / version.key / flavor
            tags = getTags(version, base, flavor)

          echo "Building and pushing $# from $#... " % [tags[0], dockerfileDir]

          generateDockerfile(version.key, base.key, flavor, labels, dockerfileDir)

          if not dryRun:
            buildAndPushImage(tags, tagPrefix, dockerfileDir)

          if save:
            echo "Saving Dockerfile to $#..." % dockerfileDir
          else:
            removeDir(dockerfileDir)

          echo "Done!"

          # Anything before this is broken and too old to fix.
          if version.key >= "0.16.0":
            echo "Testing $#... " % tags[0]

            if not dryRun:
              testImage("$#:$#" % [tagPrefix, tags[0]], flavor)

            echo "Done!"


const commands = {"build-and-push": buildAndPushImages, "setup": createBuilder}


when isMainModule:
  quit parseCommands(commands, defaultHandler = showHelp)
