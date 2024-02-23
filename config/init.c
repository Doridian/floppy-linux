#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdint.h>
#include <time.h>

int switch_root_main(char *newroot, char *newinit);

#define SQUASHFS_MAGIC 0x73717368

static int check_floppy(const char* fname) {
    int fd = open(fname, O_RDONLY);
    if (fd < 1) {
        return 0;
    }
    uint32_t fs_magic;
    if (read(fd, &fs_magic, sizeof(fs_magic)) != sizeof(fs_magic)) {
        close(fd);
        return 0;
    }
    close(fd);

    if (fs_magic == SQUASHFS_MAGIC) {
        return 1;
    }
    return 0;
}

static int fork_and_chroot_and_load_overlayfs() {
    pid_t pid = fork();
    if (pid < 0) {
        return -1;
    }
    if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        return WEXITSTATUS(status);
    }

    return execl("/floppy/bin/busybox", "chroot", "/floppy", "/sbin/modprobe", "overlay", NULL);
}

int main() {
    if(mount("none", "/dev", "devtmpfs", 0, NULL)) {
        perror("mount_devtmpfs");
        return 1;
    }

    if(mount("none", "/tmp", "tmpfs", 0, NULL)) {
        perror("mount_tmpfs");
        return 1;
    }
    if(mkdir("/tmp/work", 0755)) {
        perror("mkdir_tmp_work");
        return 1;
    }
    if(mkdir("/tmp/upper", 0755)) {
        perror("mkdir_tmp_upper");
        return 1;
    }

    printf("Scanning for root floppy...\n");

    while (1) {
        for (int i = 0; i < 10; i++) {
            char fn[32];
            sprintf(fn, "/dev/fd%d", i);
            printf("Querying device: %s\n", fn);
            if (check_floppy(fn)) {
                printf("Floppy disk detected: %s\n", fn);
                if(mount(fn, "/floppy", "squashfs", MS_RDONLY, NULL)) {
                    perror("mount_floppy");
                    return 1;
                }
                printf("Floppy disk mounted!\n");
                printf("Loading overlayfs kmod...\n");
                int overlayload = fork_and_chroot_and_load_overlayfs();
                if (overlayload) {
                    perror("fork_and_chroot_and_load_overlayfs");
                    return 1;
                }
                printf("Loading overlayfs...\n");
                if(mount("overlay", "/newroot", "overlay", 0, "lowerdir=/floppy,upperdir=/tmp/upper,workdir=/tmp/work")) {
                    perror("mount_overlay");
                    return 1;
                }
                switch_root_main("/newroot", "/sbin/init");
                perror("switch_root_main");
                return 1;
            }
        }

        printf("No floppy disk detected, hit ENTER to retry...\n");
        if (getc(stdin) <= 0) {
            sleep(1);
        }
    }

    return 1;
}
