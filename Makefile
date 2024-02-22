ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
INITRAMFS_BASE=$(ROOT_DIR)/out/initramfs

UBUNTU_SYSLINUX_ORIG=http://archive.ubuntu.com/ubuntu/pool/main/s/syslinux/syslinux_6.04~git20190206.bf6db5b4+dfsg1.orig.tar.xz
UBUNTU_SYSLINUX_PKG=http://archive.ubuntu.com/ubuntu/pool/main/s/syslinux/syslinux_6.04~git20190206.bf6db5b4+dfsg1-3ubuntu1.debian.tar.xz

LINUX_DIR=linux-6.7.5
LINUX_TARBALL=$(LINUX_DIR).tar.xz
LINUX_KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)

BUSYBOX_DIR=busybox-1.36.1
BUSYBOX_TARBALL=$(BUSYBOX_DIR).tar.bz2
BUSYBOX_URL=https://busybox.net/downloads/$(BUSYBOX_TARBALL)

BUSYBOX_DIR_INITRAMFS=$(BUSYBOX_DIR)
BUSYBOX_DIR_ROOTFS=busybox-1.36.1-rootfs

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
	cd src && cp -rp $(BUSYBOX_DIR) $(BUSYBOX_DIR_ROOTFS)
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

busyboxmenuconfig-initramfs: stamp/fetch-busybox
	cp config/busybox-initramfs.config src/$(BUSYBOX_DIR_INITRAMFS)/.config
	cd src/$(BUSYBOX_DIR_INITRAMFS) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(BUSYBOX_DIR_INITRAMFS)/.config config/busybox-initramfs.config

busyboxmenuconfig-root: stamp/fetch-busybox
	cp config/busybox-root.config src/$(BUSYBOX_DIR_ROOTFS)/.config
	cd src/$(BUSYBOX_DIR_ROOTFS) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(BUSYBOX_DIR_ROOTFS)/.config config/busybox-root.config

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

build-busybox-initramfs: stamp/fetch-busybox
	-mkdir -p out/initramfs
	cp config/busybox-initramfs.config src/$(BUSYBOX_DIR_INITRAMFS)/.config
	cd src/$(BUSYBOX_DIR_INITRAMFS) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cd src/$(BUSYBOX_DIR_INITRAMFS) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl- install
	cp -rv src/$(BUSYBOX_DIR_INITRAMFS)/_install/* out/initramfs

build-busybox-root: stamp/fetch-busybox
	-mkdir -p out/rootfs
	cp config/busybox-root.config src/$(BUSYBOX_DIR_ROOTFS)/.config
	cd src/$(BUSYBOX_DIR_ROOTFS) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cd src/$(BUSYBOX_DIR_ROOTFS) && $(MAKE) ARCH=x86 CROSS_COMPILE=i486-linux-musl- install
	cp -rv src/$(BUSYBOX_DIR_ROOTFS)/_install/* out/rootfs

build-initramfs: build-busybox-initramfs
	-rm -rf out/initramfs/dev
	-mkdir -p out/initramfs/dev

	-rm -rf out/initramfs/sys
	-mkdir -p out/initramfs/sys

	-rm -rf out/initramfs/proc
	-mkdir -p out/initramfs/proc

	cp config/init.sh out/initramfs/init
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

	mkdir -p out/rootfs/etc/init.d/
	cp etc/rc out/rootfs/etc/init.d/rc
	chmod 755 out/rootfs/etc/init.d/rc
	chown root:root out/rootfs/etc/init.d/rc

	cp etc/inittab out/rootfs/etc/inittab
	chmod 755 out/rootfs/etc/inittab
	chown root:root out/rootfs/etc/inittab

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
