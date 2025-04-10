# Nimage

A tool to build Nim Docker images and push them to Docker Hub.


## Usage

Before running the app for the first time, create a multiarch builder:

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
