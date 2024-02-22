#!/bin/sh
set -euo pipefail
set -x

mkdir -p /dev
mount -t devtmpfs none /dev

blkid /dev/fd* > /blkid.txt
cat /blkid.txt
DEVNODE="$(cat /blkid.txt | grep 'TYPE="squashfs"' | cut -d: -f1)"

mkdir -p /mnt
mount -t squashfs "$DEVNODE" /mnt

exec switch_root /mnt /sbin/init
