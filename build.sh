#!/bin/sh
set -euo pipefail

docker build -t floppylin .
docker run --rm -it -v "floppylinux_repo:/src/floppy-linux" -v "$(pwd):/repo-src" floppylin flbuild
