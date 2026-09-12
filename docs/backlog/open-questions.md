# Backlog — otwarte pozycje

Stan na 2026-09-12. Kolejność mniej więcej według wpływu na decyzję o porcie.
Każda pozycja mówi, co dokładnie jest niewiadome i co by ją zamknęło.

## 1. Renderer programowy nigdy nie został uruchomiony

SDL3 wybrał `opengl` i `setenv SDL_RENDER_DRIVER software` w Shellu tego nie
zmieniło (przebieg 2 nadal `renderer: opengl`). Nie wiadomo, czy AROS-owy
`setenv` nie dociera do `getenv()` posixc, czy SDL3 czyta ten hint inaczej.

OpenLoco ma ścieżkę programową jako fallback (`SoftwareDrawingEngine.cpp:60`),
więc to jest ścieżka, którą realnie pojedzie część użytkowników.

**Zamknie to:** wymuszenie przez `SDL_SetHint(SDL_HINT_RENDER_DRIVER, ...)` w
kodzie testu i przebieg porównawczy obu rendererów przy tym samym obciążeniu.

## 2. Wydajność — jedyna liczba, która powie, czy gra ma sens

6.1 fps przy 320x240. Pomiar pod QEMU/TCG, przez renderer OpenGL prawdopodobnie
na programowej Mesie, i zawiera narzut samego testu (76 800 pikseli
generowanych w C++ na klatkę). To nie jest liczba o sprzęcie ani o SDL3.

OpenLoco chodzi w wyższej rozdzielczości i potrzebuje wielokrotnie więcej.

**Zamknie to:** pomiar na realnej maszynie, oba renderery, przy rozdzielczości
zbliżonej do docelowej, z oddzielonym narzutem generowania pikseli.

## 3. SDL3 jako `sdl3.library`, nie statyczny build obok

Dziś linkujemy `libSDL3_static.a` zbudowaną poza systemem budowania AROS-a, bo
drzewo deadwooda (`~/Work/AROS/aros-src`) nie ma contrib w ogóle. Docelowo port
powinien używać `sdl3.library` z contrib.

**Zamknie to:** decyzja i wykonanie — wstawić mainline contrib do drzewa
ABIv11, czy utrzymywać własny build. To jest osobny projekt, nie zadanie.

## 4. `using enum` — 4 pliki, GCC 10.5 tego nie ma

`CompanyAi.cpp:3496`, `:3562`, `:3604` i sąsiedzi. To C++20 dodane w GCC 11.
Flagą się tego nie obejdzie.

**Zamknie to:** albo przepisanie tych miejsc jako łatka w `patches/openloco/`,
albo podniesienie toolchaina (AROS ma w crosstools łatki do GCC 16.2.0).
Druga droga jest szersza niż ten port i dotyczy wszystkich projektów C++.

## 5. `std::wstring_view` w `Utility/String.hpp:14` — 13 plików na ABIv11

`toUtf8(const std::wstring_view&)` to helper Windows. libstdc++ ABIv11 nie ma
`_GLIBCXX_USE_WCHAR_T`.

**Zamknie to:** owarunkowanie tej deklaracji, jako łatka. Przebudowa libstdc++
z `wchar_t` jest szersza i wymaga osobnego sprawdzenia, czy AROS ABIv11 ma po
stronie C komplet funkcji szerokoznakowych — patrz `../platform/`.

## 6. Dźwięk niesprawdzony w ogóle

`SDL_INIT_AUDIO` nie było w teście. Backend AHI w SDL3 nieruszony. Na ABIv11
`AudioEngine.cpp` nie zna `ALC_HRTF_SOFT` — SDK ma openal-soft 1.19.1 (2018).
Na mainline biblioteki OpenAL nie ma wcale, tylko nagłówki.

**Zamknie to:** test odtwarzający dźwięk przez SDL3/AHI, osobno od OpenAL-a.

## 7. Pozostałe pozycje kompilacji

- `OPENLOCO_PLATFORM` — `Version.hpp:46` nie zna `__AROS__` (4 pliki, oba ABI).
- `Platform.Posix.cpp` — brak ścieżki do własnego pliku wykonywalnego na AROS.
- makro `listen` z bsdsocket psuje `Network/Socket.h:65` (sieć niepotrzebna do
  pierwszego uruchomienia).
- `sfl::static_vector` — 4 pliki, konwersje nieprzechodzące pod GCC 10.
- `iconv.h` brak w SDK mainline (ABIv11 ma) — `Utility/String.cpp`.
- `<execution>` i TBB: `Viewport.cpp:26` i `:187`, `CMakeLists.txt:76`,
  `thirdparty/CMakeLists.txt:85-88`, `src/OpenLoco/CMakeLists.txt:758`.

## 8. Rzeczy sprawdzone tylko na jednym ABI

Wątki C++ w runtime: sprawdzone **tylko na ABIv11**. Mainline niepotwierdzony.
`hardware_concurrency()` zwraca tam 0 — OpenLoco jej nie używa, ale kolejny
projekt może.

## 9. Ścieżka „zamknij na żądanie" niesprawdzona

W żadnym przebiegu nie było `quit_event`, a ESC w przebiegu 1 nie dał zdarzenia
(program skończył 300 klatek w tej samej chwili). Gadżet zamknięcia okna
nietestowany.
