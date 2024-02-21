#!/bin/bash

set -euo pipefail
set -x

# Install x86 musl
mkdir -p /tmp/musl-download
cd /tmp/musl-download
OLD_ARCH="$(cat /etc/apk/arch)"
echo 'x86' > /etc/apk/arch
apk update --allow-untrusted
apk fetch musl --allow-untrusted
echo "$OLD_ARCH" > /etc/apk/arch
apk update
tar -xvf musl-*.apk -C /

# Fix GCC
lncross() {
    ln -s "/opt/musl-cross/bin/i486-linux-musl-$1" "/usr/local/bin/$1"
}
lncross gcc
lncross g++
lncross ar
lncross as
lncross ld

cd /repo

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
