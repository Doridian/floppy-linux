#!/bin/sh
set -eux

DISKDEV="$1"
echo "Copying disk image from $DISKDEV to /"

TMPDIR="$(mktemp -d)"
trap 'cd / && rm -rf $TMPDIR' EXIT

mount "$DISKDEV" "$TMPDIR"
cp -i -a "$TMPDIR/." /
umount "$TMPDIR"
rmdir "$TMPDIR"
