ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
INITRAMFS_BASE=$(ROOT_DIR)/out/initramfs

UBUNTU_SYSLINUX_ORIG=http://archive.ubuntu.com/ubuntu/pool/main/s/syslinux/syslinux_6.04~git20190206.bf6db5b4+dfsg1.orig.tar.xz
UBUNTU_SYSLINUX_PKG=http://archive.ubuntu.com/ubuntu/pool/main/s/syslinux/syslinux_6.04~git20190206.bf6db5b4+dfsg1-3ubuntu1.debian.tar.xz

LINUX_VERSION=6.7.5
LINUX_DIR=linux-$(LINUX_VERSION)
LINUX_TARBALL=$(LINUX_DIR).tar.xz
LINUX_KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)

BUSYBOX_DIR=busybox-1.36.1
BUSYBOX_TARBALL=$(BUSYBOX_DIR).tar.bz2
BUSYBOX_URL=https://busybox.net/downloads/$(BUSYBOX_TARBALL)

.PHONY: all clean

all: stamp/fetch-kernel \
	 stamp/fetch-busybox

	-mkdir -p stamp
	echo "Starting build ..."

stamp/download-kernel:
	-mkdir -p dist src stamp
	cd dist && wget $(LINUX_KERNEL_URL)
	touch stamp/download-kernel

stamp/fetch-kernel: stamp/download-kernel
	cd src && tar -xvf ../dist/$(LINUX_TARBALL)

	touch stamp/fetch-kernel

stamp/download-busybox:
	-mkdir -p dist src stamp
	cd dist && wget $(BUSYBOX_URL)
	touch stamp/download-busybox

stamp/fetch-busybox: stamp/download-busybox
	cd src && tar -xvf ../dist/$(BUSYBOX_TARBALL)
	touch stamp/fetch-busybox		

stamp/download-syslinux:
	-mkdir -p dist src stamp
	cd dist && wget $(UBUNTU_SYSLINUX_ORIG) -O syslinux_orig.tar.xz
	cd dist && wget $(UBUNTU_SYSLINUX_PKG) -O syslinux_pkg.tar.xz
	touch stamp/download-syslinux

stamp/fetch-syslinux: stamp/download-syslinux
	cd src && tar -xvf ../dist/syslinux_orig.tar.xz
	cd src && mv syslinux-6.04~git20190206.bf6db5b4 syslinux
	cd src/syslinux && tar -xvf ../../dist/syslinux_pkg.tar.xz
	cd src/syslinux && QUILT_PATCHES=debian/patches quilt push -a
	cd src/syslinux && patch -p1 < ../../patches/0030-fix-e88.patch
	touch stamp/fetch-syslinux

kernelmenuconfig: stamp/fetch-kernel
	cp config/kernel.config src/$(LINUX_DIR)/.config
	cd src/$(LINUX_DIR) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(LINUX_DIR)/.config config/kernel.config

busyboxmenuconfig-root: stamp/fetch-busybox
	cp config/busybox-root.config src/$(BUSYBOX_DIR)/.config
	cd src/$(BUSYBOX_DIR) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(BUSYBOX_DIR)/.config config/busybox-root.config

build-syslinux: stamp/fetch-syslinux
	cd src/syslinux && make bios PYTHON=python3 
	cd src/syslinux && make bios install INSTALLROOT=`pwd`/../../out/syslinux PYTHON=python3

download-all: stamp/download-kernel stamp/download-busybox stamp/download-syslinux
	echo OK

build-kernel: stamp/fetch-kernel build-initramfs
	-mkdir out
	-mkdir -p out/rootfs
	cp config/kernel.config src/$(LINUX_DIR)/.config
	cd src/$(LINUX_DIR) && $(MAKE) -j4 ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cp src/$(LINUX_DIR)/arch/x86/boot/bzImage out/bzImage
	cd src/$(LINUX_DIR) && INSTALL_MOD_PATH=../../out/rootfs $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl- modules_install
	depmod -b out/rootfs $(LINUX_VERSION)

build-busybox-root: stamp/fetch-busybox
	-mkdir -p out/rootfs
	cp config/busybox-root.config src/$(BUSYBOX_DIR)/.config
	cd src/$(BUSYBOX_DIR) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cd src/$(BUSYBOX_DIR) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl- install
	cp -rv src/$(BUSYBOX_DIR)/_install/* out/rootfs

build-initramfs:
	-rm -rf out/initramfs/dev
	-mkdir -p out/initramfs/dev

	-rm -rf out/initramfs/sys
	-mkdir -p out/initramfs/sys

	-rm -rf out/initramfs/proc
	-mkdir -p out/initramfs/proc

	-rm -rf out/initramfs/mnt
	-mkdir -p out/initramfs/mnt

	-rm -f out/initramfs/init
	gcc -Wall -Werror -flto -Os -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -DNDEBUG -static config/switch_root.c config/init.c -o out/initramfs/init
	chmod 755 out/initramfs/init
	chown root:root out/initramfs/init

	cd out/initramfs && \
	find . | cpio -o -H newc | xz --check=crc32 > $(ROOT_DIR)/out/initramfs.cpio.xz

build-rootfs: build-busybox-root
	-rm -rf out/rootfs/dev
	-mkdir -p out/rootfs/dev

	-rm -rf out/rootfs/sys
	-mkdir -p out/rootfs/sys

	-rm -rf out/rootfs/proc
	-mkdir -p out/rootfs/proc

	-rm -rf out/rootfs/root
	-mkdir -p out/rootfs/root

	-rm -rf out/rootfs/home
	-mkdir -p out/rootfs/home

	-rm -rf out/rootfs/tmp
	-mkdir -p out/rootfs/tmp

	-rm -rf out/rootfs/var/run
	-mkdir -p out/rootfs/var/run

	-rm -rf out/rootfs/run
	ln -s ../var/run out/rootfs/run

	mkdir -p out/rootfs/etc/init.d/ out/rootfs/etc/network/

	cp etc/rc out/rootfs/etc/init.d/rc
	chmod 755 out/rootfs/etc/init.d/rc
	chown root:root out/rootfs/etc/init.d/rc

	cp etc/inittab out/rootfs/etc/inittab
	chmod 755 out/rootfs/etc/inittab
	chown root:root out/rootfs/etc/inittab

	cp etc/passwd out/rootfs/etc/passwd
	chmod 644 out/rootfs/etc/passwd
	chown root:root out/rootfs/etc/passwd

	cp etc/group out/rootfs/etc/group
	chmod 644 out/rootfs/etc/group
	chown root:root out/rootfs/etc/group

	cp etc/hosts out/rootfs/etc/hosts
	chmod 644 out/rootfs/etc/hosts
	chown root:root out/rootfs/etc/hosts

	cp etc/hostname out/rootfs/etc/hostname
	chmod 644 out/rootfs/etc/hostname
	chown root:root out/rootfs/etc/hostname

	ln -sf /tmp/etc/resolv.conf out/rootfs/etc/resolv.conf

	echo '#!/bin/sh' > out/rootfs/usr/bin/run-parts
	echo 'exit 0' >> out/rootfs/usr/bin/run-parts
	chmod 755 out/rootfs/usr/bin/run-parts
	chown root:root out/rootfs/usr/bin/run-parts
 
	cp etc/passwd out/rootfs/etc/passwd
	chmod 644 out/rootfs/etc/passwd
	chown root:root out/rootfs/etc/passwd

	cp etc/shadow out/rootfs/etc/shadow
	chmod 600 out/rootfs/etc/shadow
	chown root:root out/rootfs/etc/shadow

	cp etc/network/interfaces out/rootfs/etc/network/interfaces
	chmod 644 out/rootfs/etc/network/interfaces
	chown root:root out/rootfs/etc/network/interfaces
 
	-mkdir -p out/rootfs/usr/share/udhcpc
	cp etc/udhcpc.script out/rootfs/usr/share/udhcpc/default.script
	chmod 755 out/rootfs/usr/share/udhcpc/default.script
	chown root:root out/rootfs/usr/share/udhcpc/default.script

	dd if=/dev/zero of=./floppy_linux2.img bs=1k count=1440
	mksquashfs out/rootfs floppy_linux2.img -noappend -comp xz -no-xattrs -no-exports
	ls -la floppy_linux2.img
	truncate -s 1440k floppy_linux2.img
	#genext2fs -L "rootfloppy" -q -m 0 -b 1440 -B 1024 -d out/rootfs floppy_linux2.img

build-floppy: build-kernel build-initramfs build-syslinux build-rootfs
	#dd if=/dev/zero of=./floppy_linux.img bs=1k count=1440
	#mkdosfs floppy_linux.img
	cp blank.img floppy_linux.img
	out/syslinux/usr/bin/syslinux --install floppy_linux.img
	mcopy -i floppy_linux.img config/syslinux.cfg ::
	mcopy -i floppy_linux.img out/bzImage  ::
	mcopy -i floppy_linux.img out/initramfs.cpio.xz  ::rootfs.ram

clean:
	echo "Making a fresh build ..."
	-rm -rf src dist stamp out
