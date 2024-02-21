#!/bin/bash

set -euo pipefail
set -x

make build-floppy

cp floppy_linux.img /repo-src/floppy_linux.img || cp floppy_linux.img /out/floppy_linux.img
cp floppy_linux2.img /repo-src/floppy_linux2.img || cp floppy_linux2.img /out/floppy_linux2.img
