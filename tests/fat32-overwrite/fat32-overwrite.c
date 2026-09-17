/* Does overwriting an existing file through POSIX O_TRUNC work on an AROS
 * FAT32 volume?
 *
 * Why this exists: OpenLoco froze - 101% host CPU, no screen change for 80 s -
 * while saving over an existing save, and fsck_msdos afterwards found
 * openloco.yml with a cluster chain running into a free cluster and FAT[0]
 * zeroed. The AROS Shell's own `copy` overwrites the same file on the same
 * volume without trouble, but `copy` opens with MODE_NEWFILE while a C++
 * std::ofstream goes through posixc with O_TRUNC. This isolates that one
 * difference, with no game and no C++ runtime in the way.
 *
 * Each step prints its result to a file, not the console: the testbench is
 * shared and a screendump cannot say whose output it is.
 *
 * Usage:  fat32-overwrite <volume:path-to-scratch-file> <report-file>
 *   e.g.  fat32-overwrite Locohome:ovtest.bin Locohome:ovtest.log
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static FILE *report;

static void say(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(report, fmt, ap);
    va_end(ap);
    fputc('\n', report);
    fflush(report);          /* the point of the exercise is surviving a hang */
}

int main(int argc, char **argv)
{
    const char *path   = argc > 1 ? argv[1] : "Locohome:ovtest.bin";
    const char *logout = argc > 2 ? argv[2] : "Locohome:ovtest.log";
    static char big[300 * 1024];
    int fd;
    ssize_t n;

    report = fopen(logout, "w");
    if (report == NULL) {
        return 20;
    }

    say("target: %s", path);

    /* 1. create it large, the way the first (working) save did */
    say("step 1: create %d bytes", (int)sizeof(big));
    memset(big, 'A', sizeof(big));
    fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0) {
        say("FAIL open for create: %s", strerror(errno));
        return 20;
    }
    n = write(fd, big, sizeof(big));
    say("  wrote %ld", (long)n);
    if (close(fd) != 0) {
        say("FAIL close: %s", strerror(errno));
        return 20;
    }
    say("  closed");

    /* 2. the suspect: reopen the EXISTING file with O_TRUNC and shrink it.
     *    If the handler hangs, the report stops here and that is the result. */
    say("step 2: reopen existing with O_TRUNC and write 6 bytes");
    fd = open(path, O_WRONLY | O_TRUNC);
    if (fd < 0) {
        say("FAIL open for truncate: %s", strerror(errno));
        return 20;
    }
    say("  opened");
    n = write(fd, "small\n", 6);
    say("  wrote %ld", (long)n);
    if (close(fd) != 0) {
        say("FAIL close: %s", strerror(errno));
        return 20;
    }
    say("  closed");

    /* 3. read it back: a successful write that cannot be read back is the
     *    corruption case, not the hang case. */
    say("step 3: read back");
    fd = open(path, O_RDONLY);
    if (fd < 0) {
        say("FAIL reopen: %s", strerror(errno));
        return 20;
    }
    memset(big, 0, 16);
    n = read(fd, big, 16);
    close(fd);
    say("  read %ld bytes: \"%.6s\"", (long)n, big);

    if (n == 6 && memcmp(big, "small\n", 6) == 0) {
        say("RESULT: PASS - O_TRUNC over an existing file works here");
        return 0;
    }
    say("RESULT: FAIL - expected 6 bytes \"small\", got %ld", (long)n);
    return 20;
}
