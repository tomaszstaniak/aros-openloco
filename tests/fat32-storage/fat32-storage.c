/* Is a FAT32 volume on AROS trustworthy storage?
 *
 * Why this exists: a 512 MB FAT32 image written only by AROS twice came back
 * with FAT[0] zeroed and orphaned clusters, and once wedged the whole guest.
 * Three controls failed to reproduce it, but each ran once on a 64 MB volume
 * with one file - far away from what the damaged volume actually saw. And no
 * run so far has done the thing that matters most: read the files back AFTER a
 * restart and compare their contents.
 *
 * So: four write patterns, kept apart so a failure can be attributed, each
 * meant for its own throwaway image, and a separate verify pass to be run in a
 * LATER boot.
 *
 *   fat32-storage <volume:> create     8 new files
 *   fat32-storage <volume:> overwrite  4 files created large, then rewritten small
 *   fat32-storage <volume:> delete     8 files created, the even ones removed
 *   fat32-storage <volume:> rotate     12 written, never more than 3 kept - what
 *                                      autosave rotation does
 *   fat32-storage <volume:> verify     read everything back and compare
 *
 * The write pass leaves "mode.txt" behind, so verify needs no arguments beyond
 * the volume and cannot be told the wrong expectation by mistake.
 *
 * Content is derived from the file number alone - file NN is (NN+1)*1024 bytes
 * of the byte (NN*7+13), and after an overwrite 1024 bytes of (NN*3+91). So
 * verify recomputes what it should see instead of trusting anything on disk.
 *
 * Reports to a file, flushed after every line: on a shared testbench the
 * console can hold another session's output, and a hang must not cost the log.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define KEEP 3            /* rotate: how many files stay */
#define ROTATE_STEPS 12
#define CREATE_FILES 8
#define OVERWRITE_FILES 4

static FILE *report;
static int failures;

static void say(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(report, fmt, ap);
    va_end(ap);
    fputc('\n', report);
    fflush(report);
}

static void fail(const char *fmt, ...)
{
    va_list ap;
    fputs("  FAIL ", report);
    va_start(ap, fmt);
    vfprintf(report, fmt, ap);
    va_end(ap);
    fputc('\n', report);
    fflush(report);
    failures++;
}

/* file NN: (NN+1)*1024 bytes of one byte value */
static unsigned char pattern_of(int n, int rewritten)
{
    return rewritten ? (unsigned char)(n * 3 + 91) : (unsigned char)(n * 7 + 13);
}
static long size_of(int n, int rewritten)
{
    return rewritten ? 1024L : (long)(n + 1) * 1024L;
}

static void path_of(char *out, size_t cap, const char *vol, const char *stem, int n)
{
    snprintf(out, cap, "%s%s%02d.bin", vol, stem, n);
}

/* returns 0 on success */
static int write_file(const char *path, unsigned char byte, long size, int truncate_existing)
{
    static unsigned char buf[64 * 1024];
    int flags = O_WRONLY | O_CREAT | (truncate_existing ? O_TRUNC : 0);
    int fd = open(path, flags, 0666);
    long left = size;

    if (fd < 0) {
        fail("open %s for write: %s", path, strerror(errno));
        return 1;
    }
    memset(buf, byte, sizeof(buf));
    while (left > 0) {
        size_t chunk = (size_t)(left < (long)sizeof(buf) ? left : (long)sizeof(buf));
        ssize_t n = write(fd, buf, chunk);
        if (n < 0) {
            fail("write %s: %s", path, strerror(errno));
            close(fd);
            return 1;
        }
        if (n == 0) {
            fail("write %s returned 0 with %ld left", path, left);
            close(fd);
            return 1;
        }
        left -= n;
    }
    if (close(fd) != 0) {
        fail("close %s: %s", path, strerror(errno));
        return 1;
    }
    return 0;
}

/* checks size and every byte; returns 0 when the file is exactly right */
static int check_file(const char *path, unsigned char byte, long size)
{
    static unsigned char buf[64 * 1024];
    long total = 0;
    int fd = open(path, O_RDONLY);
    ssize_t n;

    if (fd < 0) {
        fail("open %s for read: %s", path, strerror(errno));
        return 1;
    }
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        for (ssize_t i = 0; i < n; i++) {
            if (buf[i] != byte) {
                fail("%s: byte %ld is 0x%02x, expected 0x%02x",
                     path, total + (long)i, buf[i], byte);
                close(fd);
                return 1;
            }
        }
        total += n;
    }
    if (n < 0) {
        fail("read %s: %s", path, strerror(errno));
        close(fd);
        return 1;
    }
    close(fd);
    if (total != size) {
        fail("%s: %ld bytes, expected %ld", path, total, size);
        return 1;
    }
    say("  ok %s (%ld bytes of 0x%02x)", path, total, byte);
    return 0;
}

static int absent(const char *path)
{
    int fd = open(path, O_RDONLY);
    if (fd >= 0) {
        close(fd);
        fail("%s still exists and should not", path);
        return 1;
    }
    say("  ok %s is gone", path);
    return 0;
}

static void write_marker(const char *vol, const char *mode)
{
    char path[512];
    FILE *f;
    snprintf(path, sizeof(path), "%smode.txt", vol);
    f = fopen(path, "w");
    if (f == NULL) {
        fail("cannot write %s: %s", path, strerror(errno));
        return;
    }
    fprintf(f, "%s\n", mode);
    fclose(f);
}

static int read_marker(const char *vol, char *out, size_t cap)
{
    char path[512];
    FILE *f;
    snprintf(path, sizeof(path), "%smode.txt", vol);
    f = fopen(path, "r");
    if (f == NULL) {
        return 1;
    }
    if (fgets(out, (int)cap, f) == NULL) {
        fclose(f);
        return 1;
    }
    fclose(f);
    out[strcspn(out, "\r\n")] = '\0';
    return 0;
}

int main(int argc, char **argv)
{
    const char *vol = argc > 1 ? argv[1] : "Locotest:";
    const char *mode = argc > 2 ? argv[2] : "create";
    char logpath[512];
    char path[512];
    int i;

    snprintf(logpath, sizeof(logpath), "%s%s.log", vol, mode);
    report = fopen(logpath, "w");
    if (report == NULL) {
        return 20;
    }
    say("volume: %s   mode: %s", vol, mode);

    if (strcmp(mode, "create") == 0) {
        for (i = 0; i < CREATE_FILES; i++) {
            path_of(path, sizeof(path), vol, "f", i);
            say("create %s", path);
            if (write_file(path, pattern_of(i, 0), size_of(i, 0), 1) == 0) {
                check_file(path, pattern_of(i, 0), size_of(i, 0));
            }
        }
        write_marker(vol, mode);

    } else if (strcmp(mode, "overwrite") == 0) {
        for (i = 0; i < OVERWRITE_FILES; i++) {
            path_of(path, sizeof(path), vol, "f", i);
            say("create %s large", path);
            write_file(path, pattern_of(i, 0), 64L * 1024L, 1);
        }
        for (i = 0; i < OVERWRITE_FILES; i++) {
            path_of(path, sizeof(path), vol, "f", i);
            say("rewrite %s small, through O_TRUNC", path);
            if (write_file(path, pattern_of(i, 1), size_of(i, 1), 1) == 0) {
                check_file(path, pattern_of(i, 1), size_of(i, 1));
            }
        }
        write_marker(vol, mode);

    } else if (strcmp(mode, "delete") == 0) {
        for (i = 0; i < CREATE_FILES; i++) {
            path_of(path, sizeof(path), vol, "f", i);
            say("create %s", path);
            write_file(path, pattern_of(i, 0), size_of(i, 0), 1);
        }
        for (i = 0; i < CREATE_FILES; i += 2) {
            path_of(path, sizeof(path), vol, "f", i);
            say("delete %s", path);
            if (unlink(path) != 0) {
                fail("unlink %s: %s", path, strerror(errno));
            }
        }
        write_marker(vol, mode);

    } else if (strcmp(mode, "rotate") == 0) {
        /* what the game's autosave rotation does: write one, drop the oldest */
        for (i = 0; i < ROTATE_STEPS; i++) {
            path_of(path, sizeof(path), vol, "r", i);
            say("step %d: write %s", i, path);
            write_file(path, pattern_of(i, 0), 4L * 1024L, 1);
            if (i >= KEEP) {
                path_of(path, sizeof(path), vol, "r", i - KEEP);
                say("step %d: delete oldest %s", i, path);
                if (unlink(path) != 0) {
                    fail("unlink %s: %s", path, strerror(errno));
                }
            }
        }
        write_marker(vol, mode);

    } else if (strcmp(mode, "verify") == 0) {
        char was[64];
        if (read_marker(vol, was, sizeof(was)) != 0) {
            say("RESULT: FAIL - no mode.txt, nothing was written here");
            fclose(report);
            return 20;
        }
        say("verifying after a restart; the write pass was: %s", was);

        if (strcmp(was, "create") == 0) {
            for (i = 0; i < CREATE_FILES; i++) {
                path_of(path, sizeof(path), vol, "f", i);
                check_file(path, pattern_of(i, 0), size_of(i, 0));
            }
        } else if (strcmp(was, "overwrite") == 0) {
            for (i = 0; i < OVERWRITE_FILES; i++) {
                path_of(path, sizeof(path), vol, "f", i);
                check_file(path, pattern_of(i, 1), size_of(i, 1));
            }
        } else if (strcmp(was, "delete") == 0) {
            for (i = 0; i < CREATE_FILES; i++) {
                path_of(path, sizeof(path), vol, "f", i);
                if (i % 2 == 0) {
                    absent(path);
                } else {
                    check_file(path, pattern_of(i, 0), size_of(i, 0));
                }
            }
        } else if (strcmp(was, "rotate") == 0) {
            for (i = 0; i < ROTATE_STEPS; i++) {
                path_of(path, sizeof(path), vol, "r", i);
                if (i >= ROTATE_STEPS - KEEP) {
                    check_file(path, pattern_of(i, 0), 4L * 1024L);
                } else {
                    absent(path);
                }
            }
        } else {
            say("RESULT: FAIL - mode.txt says \"%s\", which is not a write mode", was);
            fclose(report);
            return 20;
        }

    } else {
        say("RESULT: FAIL - unknown mode \"%s\"", mode);
        fclose(report);
        return 20;
    }

    if (failures == 0) {
        say("RESULT: PASS (%s)", mode);
    } else {
        say("RESULT: FAIL (%s) - %d problem(s)", mode, failures);
    }
    fclose(report);
    return failures == 0 ? 0 : 20;
}
