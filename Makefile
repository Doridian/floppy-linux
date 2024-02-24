ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
INITRAMFS_BASE=$(ROOT_DIR)/out/initramfs

BOOTLOADER_ORIG=https://github.com/Doridian/tiny-floppy-bootloader/archive/9e977c75931f10c821d1ecaa493c48d374ede00d.tar.gz

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

stamp/download-bootloader:
	-mkdir -p dist src stamp
	cd dist && wget $(BOOTLOADER_ORIG) -O bootloader.tar.gz
	touch stamp/download-bootloader

stamp/fetch-bootloader: stamp/download-bootloader
	-mkdir -p src/bootloader
	cd src && tar -xvf ../dist/bootloader.tar.gz -C bootloader --strip-components=1
	#cd src/bootloader && patch -p0 -i ../../config/bootloader.patch
	touch stamp/fetch-bootloader

build-bootloader: stamp/fetch-bootloader
	echo OK

kernelmenuconfig: stamp/fetch-kernel
	cp config/kernel.config src/$(LINUX_DIR)/.config
	cd src/$(LINUX_DIR) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(LINUX_DIR)/.config config/kernel.config

busyboxmenuconfig: stamp/fetch-busybox
	cp config/busybox.config src/$(BUSYBOX_DIR)/.config
	cd src/$(BUSYBOX_DIR) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(BUSYBOX_DIR)/.config config/busybox.config

download-all: stamp/download-kernel stamp/download-busybox stamp/download-bootloader
	echo OK

build-kernel: stamp/fetch-kernel build-initramfs
	-mkdir out
	-mkdir -p out/rootfs
	cp config/kernel.config src/$(LINUX_DIR)/.config
	cd src/$(LINUX_DIR) && $(MAKE) -j4 ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cp src/$(LINUX_DIR)/arch/x86/boot/bzImage out/bzImage
	cd src/$(LINUX_DIR) && INSTALL_MOD_PATH=../../out/rootfs $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl- modules_install
	depmod -b out/rootfs $(LINUX_VERSION)

build-busybox: stamp/fetch-busybox
	-mkdir -p out/rootfs
	cp config/busybox.config src/$(BUSYBOX_DIR)/.config
	cd src/$(BUSYBOX_DIR) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cd src/$(BUSYBOX_DIR) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl- install
	cp -rv src/$(BUSYBOX_DIR)/_install/* out/rootfs

build-initramfs:
	-rm -rf out/initramfs/dev
	-mkdir -p out/initramfs/dev
	-rm -rf out/initramfs/floppy
	-mkdir -p out/initramfs/floppy
	-rm -rf out/initramfs/tmpfs
	-mkdir -p out/initramfs/tmpfs
	-rm -rf out/initramfs/newroot
	-mkdir -p out/initramfs/newroot

	mknod -m 622 out/initramfs/dev/console c 5 1
	mknod -m 622 out/initramfs/dev/tty0 c 4 0

	-rm -f out/initramfs/init
	i486-linux-musl-gcc -Wall -Werror -flto -Os -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -DNDEBUG -static config/init.c -o out/initramfs/init
	i486-linux-musl-strip --strip-all out/initramfs/init
	chmod 755 out/initramfs/init
	chown root:root out/initramfs/init

	cd out/initramfs && \
	find . | cpio -o -H newc > $(ROOT_DIR)/out/initramfs.cpio
	cat $(ROOT_DIR)/out/initramfs.cpio | xz --check=none > $(ROOT_DIR)/out/initramfs.cpio.xz

build-rootfs: build-busybox
	-rm -rf out/rootfs/dev
	-mkdir -p out/rootfs/dev

	-rm -rf out/rootfs/sys
	-mkdir -p out/rootfs/sys

	-rm -rf out/rootfs/proc
	-mkdir -p out/rootfs/proc

	-rm -rf out/rootfs/root
	-mkdir -p out/rootfs/root

	-rm -rf out/rootfs/overlay
	-mkdir -p out/rootfs/overlay/floppy out/rootfs/overlay/tmpfs

	-rm -rf out/rootfs/home
	-mkdir -p out/rootfs/home

	-rm -rf out/rootfs/tmp
	-mkdir -p out/rootfs/tmp

	-rm -rf out/rootfs/var/run
	-mkdir -p out/rootfs/var/run

	-rm -rf out/rootfs/run
	ln -sf var/run out/rootfs/run

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

	cp config/net.sh out/rootfs/bin/net.sh
	chmod 755 out/rootfs/bin/net.sh
	chown root:root out/rootfs/bin/net.sh

	dd if=/dev/zero of=./floppy_linux2.img bs=1k count=1440

	rm -rf out/rootfs/lib/modules/*/kernel/sound

	mksquashfs out/rootfs floppy_linux2.img -noappend -comp xz -no-xattrs -no-exports
	ls -la floppy_linux2.img
	truncate -s 1440k floppy_linux2.img
	#genext2fs -L "rootfloppy" -q -m 0 -b 1440 -B 1024 -d out/rootfs floppy_linux2.img

build-floppy: build-kernel build-initramfs build-bootloader build-rootfs
	rm -f floppy_linux.img
	cd src/bootloader && ./build.sh ../../out/bzImage ../../floppy_linux.img

clean:
	echo "Making a fresh build ..."
	-rm -rf src dist stamp out
