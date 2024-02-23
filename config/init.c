#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mount.h>
#include <stdint.h>

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

int main() {
    if(mount("none", "/dev", "devtmpfs", 0, NULL)) {
        perror("mount_devtmpfs");
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
                if(mount(fn, "/mnt", "squashfs", 0, NULL)) {
                    perror("mount_floppy");
                    return 2;
                }
                printf("Floppy disk mounted!\nRunning switch_root...\n");
                switch_root_main("/mnt", "/sbin/init");
                perror("switch_root_main");
                return 3;
            }
        }

        printf("No floppy disk detected, hit ENTER to retry...\n");
        if (getc(stdin) <= 0) {
            return 0;
        }
    }

    return 4;
}
