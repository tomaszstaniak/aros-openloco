// SDL3 + std::thread smoke test for AROS ABIv11.
//
// Answers the two questions that block the OpenLoco port and that no amount of
// host-side compiling can answer:
//   1. does contrib's SDL3 AROS backend actually open a window, give us a
//      renderer and a streaming texture, and deliver input events?
//   2. do C++ threads work at RUNTIME on this ABI? Compiling and linking
//      <thread> proves nothing about task creation or synchronisation, and
//      SDL's own threads would not prove it about libstdc++'s either.
//
// Everything is reported into a file next to the executable, never to the
// console: on the shared testbench a Shell can hold another session's output
// and a screendump cannot tell you whose.

#include <SDL3/SDL.h>

#include <chrono>
#include <cstdarg>
#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace
{
    constexpr int kWidth = 320;
    constexpr int kHeight = 240;
    constexpr int kMaxFrames = 300; // ~5s at 60fps, then exit on its own

    std::FILE* report = nullptr;

    void say(const char* fmt, ...)
    {
        va_list ap;
        va_start(ap, fmt);
        if (report != nullptr)
        {
            std::vfprintf(report, fmt, ap);
            std::fputc('\n', report);
            std::fflush(report); // a crash must not lose what we already know
        }
        va_end(ap);
    }

    // --- question 2: libstdc++ threads, independent of SDL -------------------
    struct ThreadProbe
    {
        std::mutex m;
        std::condition_variable cv;
        bool produced = false;
        int value = 0;
        std::thread::id workerId{};
    };

    bool runThreadProbe(std::string& detail)
    {
        ThreadProbe p;
        const auto mainId = std::this_thread::get_id();

        std::thread worker([&p] {
            // Do work first, then publish under the lock and notify: this
            // exercises creation, mutual exclusion and the condvar wakeup,
            // not just "a function ran somewhere".
            int sum = 0;
            for (int i = 1; i <= 1000; ++i)
                sum += i;
            {
                std::lock_guard<std::mutex> lock(p.m);
                p.value = sum;
                p.workerId = std::this_thread::get_id();
                p.produced = true;
            }
            p.cv.notify_one();
        });

        bool signalled;
        {
            std::unique_lock<std::mutex> lock(p.m);
            signalled = p.cv.wait_for(lock, std::chrono::seconds(5),
                                      [&p] { return p.produced; });
        }

        const bool joinable = worker.joinable();
        worker.join();

        const bool distinct = p.workerId != mainId && p.workerId != std::thread::id{};
        const bool correct = p.value == 500500;

        char buf[256];
        std::snprintf(buf, sizeof(buf),
                      "signalled=%d joinable=%d distinct_id=%d value=%d(expect 500500) "
                      "hw_concurrency=%u",
                      signalled, joinable, distinct, p.value,
                      std::thread::hardware_concurrency());
        detail = buf;
        return signalled && joinable && distinct && correct;
    }
}

int main(int argc, char** argv)
{
    (void)argc;
    (void)argv;
    report = std::fopen("PROGDIR:sdl3-smoke.log", "w");
    if (report == nullptr)
        report = std::fopen("sdl3-smoke.log", "w"); // hosted / non-AROS run

    const int compiled = SDL_VERSION;
    const int linked = SDL_GetVersion();
    say("sdl3-smoke on AROS ABIv11");
    say("SDL compiled=%d.%d.%d linked=%d.%d.%d revision=%s",
        SDL_VERSIONNUM_MAJOR(compiled), SDL_VERSIONNUM_MINOR(compiled),
        SDL_VERSIONNUM_MICRO(compiled), SDL_VERSIONNUM_MAJOR(linked),
        SDL_VERSIONNUM_MINOR(linked), SDL_VERSIONNUM_MICRO(linked),
        SDL_GetRevision());

    // Threads first: if this hangs we still have the log up to this line.
    std::string threadDetail;
    const bool threadsOk = runThreadProbe(threadDetail);
    say("THREADS: %s  [%s]", threadsOk ? "PASS" : "FAIL", threadDetail.c_str());

    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS))
    {
        say("SDL_Init failed: %s", SDL_GetError());
        say("RESULT: FAIL");
        std::fclose(report);
        return 1;
    }

    say("video driver: %s", SDL_GetCurrentVideoDriver());
    int numDrivers = SDL_GetNumVideoDrivers();
    for (int i = 0; i < numDrivers; ++i)
        say("  available driver %d: %s", i, SDL_GetVideoDriver(i));

    SDL_Window* window = SDL_CreateWindow("OpenLoco SDL3 smoke", kWidth, kHeight, 0);
    if (window == nullptr)
    {
        say("SDL_CreateWindow failed: %s", SDL_GetError());
        say("RESULT: FAIL");
        SDL_Quit();
        std::fclose(report);
        return 1;
    }

    // Same order OpenLoco uses in SoftwareDrawingEngine.cpp: default renderer
    // first, explicit "software" as the fallback.
    SDL_Renderer* renderer = SDL_CreateRenderer(window, nullptr);
    if (renderer == nullptr)
    {
        say("default renderer failed (%s), falling back to software", SDL_GetError());
        renderer = SDL_CreateRenderer(window, "software");
    }
    if (renderer == nullptr)
    {
        say("SDL_CreateRenderer failed: %s", SDL_GetError());
        say("RESULT: FAIL");
        SDL_DestroyWindow(window);
        SDL_Quit();
        std::fclose(report);
        return 1;
    }
    say("renderer: %s", SDL_GetRendererName(renderer));

    // OpenLoco draws into its own 8bpp buffer and presents it as one streaming
    // texture. Same shape here, in XRGB8888 to keep the test independent of
    // palette handling.
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_XRGB8888,
                                             SDL_TEXTUREACCESS_STREAMING, kWidth, kHeight);
    if (texture == nullptr)
    {
        say("SDL_CreateTexture failed: %s", SDL_GetError());
        say("RESULT: FAIL");
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        std::fclose(report);
        return 1;
    }

    std::vector<uint32_t> pixels(static_cast<size_t>(kWidth) * kHeight);
    int frames = 0;
    int keyEvents = 0;
    int mouseEvents = 0;
    bool quitRequested = false;
    bool sawQuitEvent = false;
    bool textureUpdateFailed = false;

    const uint64_t start = SDL_GetTicks();

    while (!quitRequested && frames < kMaxFrames)
    {
        SDL_Event event;
        while (SDL_PollEvent(&event))
        {
            switch (event.type)
            {
                case SDL_EVENT_QUIT:
                    sawQuitEvent = true;
                    quitRequested = true;
                    break;
                case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                    sawQuitEvent = true;
                    quitRequested = true;
                    break;
                case SDL_EVENT_KEY_DOWN:
                    ++keyEvents;
                    say("key down: scancode=%d key=%d", event.key.scancode, event.key.key);
                    if (event.key.scancode == SDL_SCANCODE_ESCAPE)
                        quitRequested = true;
                    break;
                case SDL_EVENT_MOUSE_MOTION:
                case SDL_EVENT_MOUSE_BUTTON_DOWN:
                    ++mouseEvents;
                    break;
                default:
                    break;
            }
        }

        // Animated gradient so a stuck frame is visible on a screendump.
        for (int y = 0; y < kHeight; ++y)
        {
            for (int x = 0; x < kWidth; ++x)
            {
                const uint8_t r = static_cast<uint8_t>(x + frames);
                const uint8_t g = static_cast<uint8_t>(y + frames * 2);
                const uint8_t b = static_cast<uint8_t>(frames * 3);
                pixels[static_cast<size_t>(y) * kWidth + x] =
                    (static_cast<uint32_t>(r) << 16) | (static_cast<uint32_t>(g) << 8) | b;
            }
        }

        if (!SDL_UpdateTexture(texture, nullptr, pixels.data(), kWidth * 4))
        {
            if (!textureUpdateFailed)
                say("SDL_UpdateTexture failed: %s", SDL_GetError());
            textureUpdateFailed = true;
        }

        SDL_RenderClear(renderer);
        SDL_RenderTexture(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);
        ++frames;
    }

    const uint64_t elapsed = SDL_GetTicks() - start;
    say("frames=%d elapsed_ms=%llu key_events=%d mouse_events=%d quit_event=%d",
        frames, static_cast<unsigned long long>(elapsed), keyEvents, mouseEvents,
        static_cast<int>(sawQuitEvent));
    if (elapsed > 0)
        say("fps=%.1f", frames * 1000.0 / static_cast<double>(elapsed));

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    const bool videoOk = frames > 0 && !textureUpdateFailed;
    say("VIDEO: %s", videoOk ? "PASS" : "FAIL");
    say("RESULT: %s", (videoOk && threadsOk) ? "PASS" : "FAIL");
    std::fclose(report);
    return (videoOk && threadsOk) ? 0 : 1;
}
