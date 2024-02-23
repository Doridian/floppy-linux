#include <sys/vfs.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <dirent.h>
#include <fcntl.h>
#include <string.h>

#ifndef MS_MOVE
# define MS_MOVE     8192
#endif

int switch_root_main(char *newroot, char *newinit)
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
