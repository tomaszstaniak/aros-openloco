// C++ runtime checks for an AROS ABI, one step at a time.
//
// Written for mainline v1, where OpenLoco starts, initialises OpenAL, then
// calls abort() minutes later with nothing in its log. The usual causes of a
// silent abort in a C++ program are a throw that cannot unwind, a thread that
// cannot start, or a static initialiser that fails - so each of those is tried
// here in isolation, with every step printed and flushed before it is taken.
// The last line on screen is the one that failed.

#include <cstdio>
#include <filesystem>
#include <stdexcept>
#include <string>
#include <thread>

namespace
{
    void step(const char* what)
    {
        std::printf("  %s\n", what);
        std::fflush(stdout);
    }

    struct StaticProbe
    {
        int value;
        StaticProbe()
            : value(42)
        {
        }
    };
    StaticProbe staticProbe;

    [[gnu::noinline]] void thrower(int depth)
    {
        if (depth == 0)
            throw std::runtime_error("thrown three frames down");
        thrower(depth - 1);
    }
}

int main()
{
    std::printf("cxx-runtime\n");

    step("static initialiser ran");
    std::printf("    value = %d (expect 42)\n", staticProbe.value);

    step("throw and catch in one frame");
    try
    {
        throw std::runtime_error("local");
    }
    catch (const std::exception& e)
    {
        std::printf("    caught: %s\n", e.what());
    }

    step("throw three frames down, catch here");
    try
    {
        thrower(3);
    }
    catch (const std::exception& e)
    {
        std::printf("    caught: %s\n", e.what());
    }

    step("std::thread start and join");
    int fromThread = 0;
    std::thread t([&fromThread] { fromThread = 7; });
    t.join();
    std::printf("    thread wrote %d (expect 7)\n", fromThread);

    step("std::filesystem::exists on the current directory");
    std::error_code ec;
    bool here = std::filesystem::exists(".", ec);
    std::printf("    exists = %d, error = %s\n", here ? 1 : 0, ec.message().c_str());

    step("std::filesystem throwing overload on a missing path");
    try
    {
        (void)std::filesystem::file_size("this-file-does-not-exist");
    }
    catch (const std::filesystem::filesystem_error& e)
    {
        std::printf("    caught filesystem_error\n");
    }

    step("done - all steps returned");
    return 0;
}
