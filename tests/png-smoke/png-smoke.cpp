// libpng + zlib smoke test for AROS: does a statically linked PNG path work,
// with no png.library and no z1.library behind it?
//
// The SDK's libpng.a and libz.a are link stubs into png.library / z1.library,
// so linking -lpng -lz ties the program to whatever version of those libraries
// the user's machine happens to have. (An inherited note said z1.library is
// absent on AROS One; on our AROS One 1.3 it is in fact present — checked in
// the guest 2026-09-13. The static route is chosen for independence from the
// machine, not because the library is missing.) The static archives
// libpng_nostdio.a / libz.static.a are the answer, but "the symbols resolve"
// is not the same as "it reads and writes a PNG", so this does both for real.
//
// Deliberately mirrors OpenLoco's own usage rather than the easy path:
// png_set_write_fn (Ui/Screenshot.cpp:96) and png_set_read_fn
// (Gfx/src/PngImage.cpp:73), never png_init_io — which is exactly the call
// libpng_nostdio does not have.

#include <png.h>
#include <zlib.h>

#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <csetjmp>
#include <string>
#include <vector>

namespace
{
    constexpr int kWidth = 64;
    constexpr int kHeight = 48;

    std::FILE* report = nullptr;

    void say(const char* fmt, ...)
    {
        va_list ap;
        va_start(ap, fmt);
        if (report != nullptr)
        {
            std::vfprintf(report, fmt, ap);
            std::fputc('\n', report);
            std::fflush(report);
        }
        va_end(ap);
    }

    // A byte sink/source, so the whole test stays in memory and cannot be
    // confused by filesystem behaviour.
    struct Buffer
    {
        std::vector<unsigned char> bytes;
        size_t readPos = 0;
    };

    void writeData(png_structp png, png_bytep data, png_size_t length)
    {
        auto* buf = static_cast<Buffer*>(png_get_io_ptr(png));
        buf->bytes.insert(buf->bytes.end(), data, data + length);
    }

    void flushData(png_structp) {}

    void readData(png_structp png, png_bytep data, png_size_t length)
    {
        auto* buf = static_cast<Buffer*>(png_get_io_ptr(png));
        if (buf->readPos + length > buf->bytes.size())
        {
            png_error(png, "read past end");
            return;
        }
        std::memcpy(data, buf->bytes.data() + buf->readPos, length);
        buf->readPos += length;
    }

    std::vector<unsigned char> makeImage()
    {
        std::vector<unsigned char> px(static_cast<size_t>(kWidth) * kHeight * 3);
        for (int y = 0; y < kHeight; ++y)
            for (int x = 0; x < kWidth; ++x)
            {
                unsigned char* p = &px[(static_cast<size_t>(y) * kWidth + x) * 3];
                p[0] = static_cast<unsigned char>(x * 4);
                p[1] = static_cast<unsigned char>(y * 5);
                p[2] = static_cast<unsigned char>((x ^ y) * 3);
            }
        return px;
    }

    bool encode(const std::vector<unsigned char>& px, Buffer& out)
    {
        png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
        if (png == nullptr)
            return false;
        png_infop info = png_create_info_struct(png);
        if (info == nullptr)
        {
            png_destroy_write_struct(&png, nullptr);
            return false;
        }
        if (setjmp(png_jmpbuf(png)))
        {
            png_destroy_write_struct(&png, &info);
            return false;
        }
        png_set_write_fn(png, &out, writeData, flushData);
        png_set_IHDR(png, info, kWidth, kHeight, 8, PNG_COLOR_TYPE_RGB,
                     PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
        png_write_info(png, info);
        std::vector<png_bytep> rows(kHeight);
        for (int y = 0; y < kHeight; ++y)
            rows[y] = const_cast<png_bytep>(px.data() + static_cast<size_t>(y) * kWidth * 3);
        png_write_image(png, rows.data());
        png_write_end(png, nullptr);
        png_destroy_write_struct(&png, &info);
        return true;
    }

    bool decode(Buffer& in, std::vector<unsigned char>& px, int& w, int& h)
    {
        png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
        if (png == nullptr)
            return false;
        png_infop info = png_create_info_struct(png);
        if (info == nullptr)
        {
            png_destroy_read_struct(&png, nullptr, nullptr);
            return false;
        }
        if (setjmp(png_jmpbuf(png)))
        {
            png_destroy_read_struct(&png, &info, nullptr);
            return false;
        }
        png_set_read_fn(png, &in, readData);
        png_read_info(png, info);
        w = static_cast<int>(png_get_image_width(png, info));
        h = static_cast<int>(png_get_image_height(png, info));
        png_read_update_info(png, info);
        px.assign(static_cast<size_t>(w) * h * 3, 0);
        std::vector<png_bytep> rows(h);
        for (int y = 0; y < h; ++y)
            rows[y] = px.data() + static_cast<size_t>(y) * w * 3;
        png_read_image(png, rows.data());
        png_destroy_read_struct(&png, &info, nullptr);
        return true;
    }
}

int main()
{
    report = std::fopen("PROGDIR:png-smoke.log", "w");
    if (report == nullptr)
        report = std::fopen("png-smoke.log", "w");

    say("png-smoke on AROS");
    say("libpng compiled=%s linked=%s", PNG_LIBPNG_VER_STRING, png_get_libpng_ver(nullptr));
    say("zlib   compiled=%s linked=%s", ZLIB_VERSION, zlibVersion());

    const auto original = makeImage();

    Buffer encoded;
    if (!encode(original, encoded))
    {
        say("ENCODE: FAIL");
        say("RESULT: FAIL");
        std::fclose(report);
        return 1;
    }
    const bool signature = encoded.bytes.size() > 8 && encoded.bytes[1] == 'P' &&
        encoded.bytes[2] == 'N' && encoded.bytes[3] == 'G';
    say("ENCODE: %s  bytes=%zu png_signature=%d",
        signature ? "PASS" : "FAIL", encoded.bytes.size(), static_cast<int>(signature));

    // Compression actually running is what proves zlib is linked in, not
    // merely resolved: raw RGB here is 9216 bytes.
    say("raw=%d compressed=%zu", kWidth * kHeight * 3, encoded.bytes.size());

    std::vector<unsigned char> roundTripped;
    int w = 0, h = 0;
    if (!decode(encoded, roundTripped, w, h))
    {
        say("DECODE: FAIL");
        say("RESULT: FAIL");
        std::fclose(report);
        return 1;
    }

    const bool sameSize = w == kWidth && h == kHeight;
    const bool samePixels = sameSize && roundTripped == original;
    say("DECODE: %s  %dx%d pixels_identical=%d",
        (sameSize && samePixels) ? "PASS" : "FAIL", w, h, static_cast<int>(samePixels));

    const bool ok = signature && sameSize && samePixels;
    say("RESULT: %s", ok ? "PASS" : "FAIL");
    std::fclose(report);
    return ok ? 0 : 1;
}
