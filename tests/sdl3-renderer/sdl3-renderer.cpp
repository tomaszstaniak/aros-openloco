// Minimal reproducer: SDL3 on AROS refuses a renderer for a HIDDEN window,
// and says nothing about why.
//
// Found while porting OpenLoco. The game creates its window hidden - upstream
// behaviour, and normal SDL usage - then asks for a renderer before showing
// it. On AROS that request is refused and the caller is handed the software
// renderer instead. Created visible, the identical request succeeds.
//
// Two problems, related but separate, and this program is meant to be small
// enough to attach to a report of either:
//
//   1. the refusal itself, which depends only on the window's visibility;
//   2. no diagnosis: SDL_GetError() is read IMMEDIATELY after the failed call,
//      before anything else touches SDL, and comes back empty.
//
// It also prints GL_VENDOR / GL_RENDERER / GL_VERSION, because "the GL here is
// a software implementation" is worth establishing from the driver's own
// identification rather than inferred from it being slow.
//
// Everything goes to stdout and to a report file next to the executable: on
// AROS the Shell keeps stdout only, and a program that crashes should still
// leave behind what it had already found.

#include <SDL3/SDL.h>
#include <GL/gl.h>

#include <cstdarg>
#include <cstdio>
#include <initializer_list>

namespace
{
    constexpr int kWidth = 640;
    constexpr int kHeight = 480;

    std::FILE* report = nullptr;

    void say(const char* fmt, ...)
    {
        va_list ap;
        va_start(ap, fmt);
        std::vprintf(fmt, ap);
        std::putchar('\n');
        std::fflush(stdout);
        va_end(ap);

        if (report != nullptr)
        {
            va_start(ap, fmt);
            std::vfprintf(report, fmt, ap);
            std::fputc('\n', report);
            std::fflush(report);
            va_end(ap);
        }
    }

    SDL_Window* makeWindow(bool hidden)
    {
        SDL_PropertiesID props = SDL_CreateProperties();
        SDL_SetStringProperty(props, SDL_PROP_WINDOW_CREATE_TITLE_STRING, "renderer probe");
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, kWidth);
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, kHeight);
        SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN, hidden);
        SDL_Window* w = SDL_CreateWindowWithProperties(props);
        SDL_DestroyProperties(props);
        return w;
    }

    // One case: a fresh window of the given visibility, one renderer request,
    // and the error text read before anything else can clear or overwrite it.
    void probe(bool hidden, const char* driver)
    {
        const char* vis = hidden ? "hidden" : "visible";
        const char* want = driver != nullptr ? driver : "(default)";

        SDL_Window* window = makeWindow(hidden);
        if (window == nullptr)
        {
            say("%-7s  %-9s  WINDOW FAILED: %s", vis, want, SDL_GetError());
            return;
        }

        SDL_ClearError();
        SDL_Renderer* r = SDL_CreateRenderer(window, driver);
        // Nothing between the call and this read. That is the point.
        const char* err = SDL_GetError();
        const bool hasText = err != nullptr && *err != '\0';

        if (r == nullptr)
        {
            say("%-7s  %-9s  REFUSED    error text: %s",
                vis, want, hasText ? err : "<none - SDL set no error>");
        }
        else
        {
            const char* got = SDL_GetRendererName(r);
            say("%-7s  %-9s  granted    %s", vis, want, got != nullptr ? got : "?");
            SDL_DestroyRenderer(r);
        }

        // Deliberately NOT SDL_DestroyWindow(). Destroying a HIDDEN window
        // crashes this guest: "Error 0x80000003 - Illegal address access" in
        // AROS_CloseWindowSafely, which closes an Intuition window that was
        // never opened for a hidden SDL window. That is a third finding, and
        // it may well belong to our own hidden-window patch rather than to
        // the stock backend - it has not been checked against an unpatched
        // SDL3. Leaking a handful of windows costs nothing in a probe that
        // exits seconds later, and it keeps this program able to finish.
        (void)window;
    }

    // Who is actually answering the GL calls. A software rasteriser says so
    // here; low frame rates on their own do not.
    void identifyGL()
    {
        SDL_Window* w = SDL_CreateWindow("gl probe", kWidth, kHeight, SDL_WINDOW_OPENGL);
        if (w == nullptr)
        {
            say("GL: no SDL_WINDOW_OPENGL window: %s", SDL_GetError());
            return;
        }
        SDL_GLContext ctx = SDL_GL_CreateContext(w);
        if (ctx == nullptr)
        {
            say("GL: no context: %s", SDL_GetError());
            SDL_DestroyWindow(w);
            return;
        }

        const GLubyte* vendor = glGetString(GL_VENDOR);
        const GLubyte* renderer = glGetString(GL_RENDERER);
        const GLubyte* version = glGetString(GL_VERSION);
        say("GL_VENDOR   %s", vendor != nullptr ? (const char*)vendor : "?");
        say("GL_RENDERER %s", renderer != nullptr ? (const char*)renderer : "?");
        say("GL_VERSION  %s", version != nullptr ? (const char*)version : "?");

        SDL_GL_DestroyContext(ctx);
        SDL_DestroyWindow(w);
    }
}

int main(int, char**)
{
    report = std::fopen("renderer-probe.txt", "w");

    if (!SDL_Init(SDL_INIT_VIDEO))
    {
        say("SDL_Init(VIDEO) failed: %s", SDL_GetError());
        return 1;
    }

    say("SDL %d.%d.%d, video driver: %s",
        SDL_VERSIONNUM_MAJOR(SDL_GetVersion()),
        SDL_VERSIONNUM_MINOR(SDL_GetVersion()),
        SDL_VERSIONNUM_MICRO(SDL_GetVersion()),
        SDL_GetCurrentVideoDriver());

    say("render drivers built in:");
    for (int i = 0; i < SDL_GetNumRenderDrivers(); ++i)
    {
        say("  %d. %s", i, SDL_GetRenderDriver(i));
    }

    // A/B/A. The first run of this program put the visible cases first and the
    // hidden ones failed for every driver, including "software" - which the
    // game gets on a hidden window every time. So either the game and this
    // differ somewhere else, or the outcome depends on what was created and
    // destroyed before. Running hidden, then visible, then hidden again tells
    // those two apart without changing anything else.
    say("");
    say("window   asked for  result");
    say("-- pass 1: hidden first, nothing created before --");
    for (const char* d : { (const char*)nullptr, "opengl", "software" })
    {
        probe(true, d);
    }
    say("-- pass 2: visible --");
    for (const char* d : { (const char*)nullptr, "opengl", "software" })
    {
        probe(false, d);
    }
    say("-- pass 3: hidden again, after the visible windows --");
    for (const char* d : { (const char*)nullptr, "opengl", "software" })
    {
        probe(true, d);
    }

    say("");
    identifyGL();

    SDL_Quit();
    if (report != nullptr)
    {
        std::fclose(report);
    }
    return 0;
}
