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

#ifndef MS_MOVE
# define MS_MOVE     8192
#endif

#define SQUASHFS_MAGIC 0x73717368

static int switch_root_main(char *newroot, char *newinit)
{
	if (chdir(newroot)) {
		perror("chdir_newroot");
		return 1;
	}

	if (mount(".", "/", NULL, MS_MOVE, NULL)) {
		perror("mount_move_root");
        return 1;
	}

	if (unlink("/init")) {
		perror("unlink_init");
		return 1;
	}

	chroot(".");
    chdir("/");

	execl(newinit, newinit, NULL);
	perror("exec_init");
    return 1;
}

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

static int load_overlay_kmod() {
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

    if(mount("none", "/tmpfs", "tmpfs", 0, NULL)) {
        perror("mount_tmpfs");
        return 1;
    }
    if(mkdir("/tmpfs/work", 0755)) {
        perror("mkdir_tmpfs_work");
        return 1;
    }
    if(mkdir("/tmpfs/upper", 0755)) {
        perror("mkdir_tmpfs_upper");
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
                printf("Loading overlay kmod...\n");
                if (load_overlay_kmod()) {
                    perror("load_overlay_kmod");
                    return 1;
                }
                printf("Mounting overlay...\n");
                if(mount("overlay", "/newroot", "overlay", 0, "lowerdir=/floppy,upperdir=/tmpfs/upper,workdir=/tmpfs/work")) {
                    perror("mount_overlay");
                    return 1;
                }
                printf("Mounting /overlay/floppy...\n");
                if(mount(fn, "/newroot/overlay/floppy", "squashfs", MS_RDONLY, NULL)) {
                    perror("mount_floppyroot");
                    return 1;
                }
                printf("Mounting /overlay/tmpfs...\n");
                if (mount("/tmpfs", "/newroot/overlay/tmpfs", NULL, MS_BIND, NULL)) {
                    perror("mount_bind_tmp");
                    return 1;
                }
                printf("Switching root...\n");
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
