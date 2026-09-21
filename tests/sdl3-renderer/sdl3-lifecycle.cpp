// One window lifecycle per process, for locating the SDL_DestroyWindow() crash
// on AROS (backlog item 24c).
//
//   sdl3-lifecycle hidden-bare     hidden window, no renderer, destroy
//   sdl3-lifecycle hidden-software hidden window, software renderer, destroy both
//   sdl3-lifecycle visible-opengl  visible window, opengl renderer, destroy both
//   sdl3-lifecycle sequence        visible-opengl, then hidden-software, in one
//                                  process: the order that made the first
//                                  renderer probe refuse every hidden request
//
// One case per process on purpose: a crash takes the process with it, and a
// previous case's windows, surfaces or closed display must not change the
// conditions of the next. The renderer, when there is one, is destroyed before
// the window, as SDL expects.
//
// Every step is printed before it is taken and flushed, so the last line on
// screen is the step that crashed.

#include <SDL3/SDL.h>

#include <cstdio>
#include <cstring>

namespace
{
    void step(const char* what)
    {
        std::printf("  %s\n", what);
        std::fflush(stdout);
    }

    SDL_Window* makeWindow(bool hidden)
    {
        SDL_PropertiesID props = SDL_CreateProperties();
        SDL_SetStringProperty(props, SDL_PROP_WINDOW_CREATE_TITLE_STRING, "lifecycle");
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, 640);
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, 480);
        SDL_SetBooleanProperty(props, SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN, hidden);
        SDL_Window* w = SDL_CreateWindowWithProperties(props);
        SDL_DestroyProperties(props);
        return w;
    }

    // One full create/destroy cycle; returns false if the renderer was refused.
    bool cycle(bool hidden, const char* driver)
    {
        std::printf(" %s window, %s renderer\n", hidden ? "hidden" : "visible", driver);
        step("create window");
        SDL_Window* w = makeWindow(hidden);
        step("create renderer");
        SDL_ClearError();
        SDL_Renderer* r = SDL_CreateRenderer(w, driver);
        const char* e = SDL_GetError();
        if (r == nullptr)
            std::printf("  renderer REFUSED: %s\n", (e && *e) ? e : "<no error text>");
        else
            std::printf("  renderer granted: %s\n", SDL_GetRendererName(r));
        std::fflush(stdout);
        if (r != nullptr)
        {
            step("destroy renderer");
            SDL_DestroyRenderer(r);
        }
        step("destroy window");
        SDL_DestroyWindow(w);
        return r != nullptr;
    }

    int sequence()
    {
        std::printf("case sequence\n");
        if (!SDL_Init(SDL_INIT_VIDEO))
            return 1;
        cycle(false, "opengl");
        cycle(true, "software");
        cycle(true, "software");
        step("SDL_Quit");
        SDL_Quit();
        step("done - no crash");
        return 0;
    }
}

int main(int argc, char** argv)
{
    const char* c = argc > 1 ? argv[1] : "";
    if (std::strcmp(c, "sequence") == 0)
        return sequence();
    const bool hidden = std::strncmp(c, "hidden", 6) == 0;
    const char* driver = nullptr;
    if (std::strcmp(c, "hidden-software") == 0)
        driver = "software";
    else if (std::strcmp(c, "visible-opengl") == 0)
        driver = "opengl";
    else if (std::strcmp(c, "hidden-bare") != 0)
    {
        std::printf("usage: sdl3-lifecycle hidden-bare|hidden-software|visible-opengl|sequence\n");
        return 2;
    }

    std::printf("case %s\n", c);
    if (!SDL_Init(SDL_INIT_VIDEO))
    {
        std::printf("  SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    step("create window");
    SDL_Window* w = makeWindow(hidden);
    if (w == nullptr)
    {
        std::printf("  window failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Renderer* r = nullptr;
    if (driver != nullptr)
    {
        step("create renderer");
        SDL_ClearError();
        r = SDL_CreateRenderer(w, driver);
        const char* e = SDL_GetError();
        if (r == nullptr)
            std::printf("  renderer REFUSED: %s\n", (e && *e) ? e : "<no error text>");
        else
            std::printf("  renderer granted: %s\n", SDL_GetRendererName(r));
        std::fflush(stdout);
    }

    if (r != nullptr)
    {
        step("destroy renderer");
        SDL_DestroyRenderer(r);
    }
    step("destroy window");
    SDL_DestroyWindow(w);
    step("SDL_Quit");
    SDL_Quit();
    step("done - no crash");
    return 0;
}
