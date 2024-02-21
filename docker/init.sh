#!/bin/bash

set -euo pipefail
set -x

# Install x86 musl
mkdir -p /tmp/apk-download
cd /tmp/apk-download
OLD_ARCH="$(cat /etc/apk/arch)"
echo 'x86' > /etc/apk/arch
apk update --allow-untrusted
apk fetch musl libuuid util-linux-dev --allow-untrusted
echo "$OLD_ARCH" > /etc/apk/arch
apk update

tar -xvf musl-*.apk -C / lib/
tar -xvf libuuid-*.apk -C /opt/musl-cross/ lib/
tar -xvf util-linux-dev-*.apk -C /opt/musl-cross/i486-linux-musl/ --strip-components=1 usr/

# Fix GCC
lncross() {
    ln -s "/opt/musl-cross/bin/i486-linux-musl-$1" "/usr/local/bin/$1"
}
lncross gcc
lncross g++
lncross ar
lncross as
lncross ld
lncross objcopy
lncross ranlib
lncross objdump
lncross nm


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
