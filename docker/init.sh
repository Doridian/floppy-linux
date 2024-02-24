#!/bin/bash

set -euo pipefail
set -x

if [ -d /repo-src/.git ];
then
    rsync -a /repo-src/ /src/floppy-linux/ --exclude=out --exclude=src
else
    git clone https://github.com/Doridian/floppy-linux.git /src/floppy-linux
fi
cd /src/floppy-linux
mkdir -p dist out src stamp

make download-all

exec /bin/bash
