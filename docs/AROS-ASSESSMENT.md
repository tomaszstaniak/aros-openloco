# OpenLoco na AROS ABIv11 i mainline v1

Ocena z 2026-09-12. Zakres: natywne AROS x86_64, dwa osobne ABI.
**Cel główny: ABIv11.** mainline v1 jako drugi target.

Backlog otwartych pozycji: `docs/backlog/open-questions.md`.
Zasady wspólne: `../../AGENTS.md`, fakty o platformie: `../../docs/platform/`.

## Wynik

**Port jest wykonalny i nie wymaga pisania backendu od podstaw.** Gra jest od
grudnia 2025 w całości przepisana na C++ — nie ma już hooków w oryginalny
`loco.exe` ani kodu x86, który blokował port przez dekadę. Cały dostęp do
sprzętu idzie przez SDL3, a AROS ma natywny port SDL3 w contrib.

| | ABIv11 (cel główny) | mainline v1 |
|---|---|---|
| Pliki .cpp kompilujące się bez zmian | **366 / 394** | **379 / 394** |
| SDL3 | brak w drzewie deadwooda | jest w `contrib/SDL3` |
| OpenAL w SDK | `libopenal.a` jest, ale bez HRTF | nagłówki `AL/` są, biblioteki brak |
| iconv w SDK | jest | brak |

Oba ABI są blisko siebie. Różnica to 13 plików, które na ABIv11 wymagają
`std::wstring_view`.

Repozytorium: https://github.com/OpenLoco/OpenLoco
Commit: `af445f8dc6632c6341fc7b26c3246685406e6815` (2026-09-10), wersja 26.08.

## Czego OpenLoco faktycznie potrzebuje

Z `thirdparty/CMakeLists.txt`, nie z README:

- **SDL3** (`find_package(SDL3 REQUIRED CONFIG)`) — jedyna twarda zależność GUI.
- **OpenAL** — cały dźwięk, `src/Audio/src/AudioEngine.cpp` używa `AL/al.h`,
  `AL/alc.h`, `AL/alext.h`.
- **libpng + zlib** — oba SDK mają.
- **fmt 11.1.4, sfl 2.2.0, yaml-cpp 0.9.0** — pobierane przez CMake, czysty C++.
- **TBB** — przez `<execution>`. Szerzej niżej; to nie jest zmiana jednej linii.
- **libzip** — **nie jest używane.** README je wymienia, ale w całym drzewie nie
  ma ani jednego `#include <zip.h>`. To martwy wpis w dokumentacji.
- **breakpad** — tylko pod MSVC.

Konfiguracja CMake z toolchainem ABIv11 przechodzi wykrywanie kompilatora,
C++20, `Threads` i `__GLIBCXX__`, a zatrzymuje się dokładnie na `find_package(SDL3)`.

## Stan toolchainów

Oba ABI mają **GCC 10.5.0**. Upstream buduje GCC 13+.

```
__cpp_concepts 201907   __cpp_lib_concepts 202002   __cpp_lib_ranges 201911
__cpp_lib_span 202002   __cpp_lib_jthread 201911    __cpp_lib_atomic_ref 201806
_GLIBCXX_HAS_GTHREADS 1
```

**GCC 10.5.0 wystarcza tylko po adaptacji kodu.** Makra powyżej mówią o
bibliotece, nie o języku: `using enum` to C++20 wprowadzone dopiero w GCC 11 i
w czterech plikach OpenLoco kończy się błędem składni (`CompanyAi.cpp:3496`,
`:3562`, `:3604` i dalej). Tego nie da się obejść flagą — trzeba przepisać te
miejsca albo podnieść toolchain. AROS ma w `tools/crosstools/gnu/` łatki aż do
GCC 16.2.0, więc podniesienie nie jest ślepą uliczką.

`std::bit_cast` i `std::format` brakuje (GCC 11+), ale OpenLoco nie używa
żadnego z nich — sprawdzone grepem po całym `src/`.

### Wątki: sprawdzone w runtime na ABIv11

`_GLIBCXX_HAS_GTHREADS 1` na obu ABI, a `tools/crosstools/gnu/gcc-15.2.0-aros.diff`
ustawia `thread_file=posix` oraz `LIBSTDCXX_PTHREAD "pthread"`. To były tylko
przesłanki; **rozstrzygnęło uruchomienie na maszynie AROS One (ABIv11)**:
`std::thread` startuje, `std::mutex` i `std::condition_variable` przenoszą
wynik, `wait_for` budzi się przez predykat, worker ma inny `thread::id`, `join()`
wraca. Szczegóły i log: `docs/evidence/sdl3-abiv11/RESULTS.md`.

Zastrzeżenia: sprawdzone **tylko na ABIv11** — mainline nadal niepotwierdzony —
i `std::thread::hardware_concurrency()` zwraca tam `0` (OpenLoco jej nie używa).

## ABIv11: brak wchar_t w libstdc++

```
abiv11:  #define _GLIBCXX_USE_C99_WCHAR _GLIBCXX11_USE_C99_WCHAR
abiv1:   #define _GLIBCXX_USE_C99_WCHAR _GLIBCXX11_USE_C99_WCHAR
         #define _GLIBCXX_USE_WCHAR_T 1
```

libstdc++ ABIv11 zbudowano **bez** `_GLIBCXX_USE_WCHAR_T`, więc `std::wstring`
i `std::wstring_view` nie istnieją. Mainline je ma. Wychodzi to w dwóch
miejscach:

1. **fmt 11.1.4**, `format.h:1271` — jedna linia w helperze dla `wchar_t`,
   którego OpenLoco nigdy nie wywołuje. Nagłówek wchodzi wszędzie, więc ta
   jedna linia przewracała 334 pliki.
2. **`src/Utility/include/OpenLoco/Utility/String.hpp:14`** —
   `std::string toUtf8(const std::wstring_view& src)`. To helper dla Windows.
   Po naprawie fmt zostaje 13 plików, które o niego zahaczają.

**Nie zaczynać od przebudowy libstdc++.** Lokalny patch przypiętej wersji fmt
(`patches/dependencies/fmt-11.1.4-aros-nowstring.diff`, strażnik na
`_GLIBCXX_USE_WCHAR_T`) załatwia punkt 1 od ręki i pozwala zobaczyć, co
naprawdę blokuje grę — co się potwierdziło, bo dopiero po nim ujawniły się
`wstring_view` i `ALC_HRTF_SOFT`. Przebudowa biblioteki standardowej ma
znacznie szerszy zakres, dotyczy każdego kolejnego portu C++ i wymaga osobnego
sprawdzenia, czy AROS ABIv11 ma po stronie C komplet funkcji szerokoznakowych.
To osobna decyzja, nie krok w tym porcie.

## Wynik próby kompilacji

Kompilacja do plików obiektowych, bez linkowania. 394 pliki `.cpp` z `src/`
(pominięte `Platform.Windows.cpp`, `Platform.Macos.mm`, `Crash.cpp` — backendy
nie nasze). Flagi z `cmake/OpenLocoCommon.cmake`:
`-std=c++20 -fno-char8_t -fstrict-aliasing -O1 -DFMT_HEADER_ONLY=1`.
SDL3 z nagłówków upstreamowych 3.4.12 **z nałożoną łatką AROS z contrib**.
Jedyna zmiana poza źródłami gry to patch fmt opisany wyżej.

| | ABIv11 | mainline v1 |
|---|---|---|
| Kompilator | GCC 10.5.0, `~/Work/AROS/toolchain` | GCC 10.5.0, `/Volumes/arosmain/toolchain-mainline` |
| SDK | `~/Work/AROS/sdk` | `/Volumes/arosmain/build/bin/pc-x86_64/AROS/Developer` |
| **OK** | **366 / 394** | **379 / 394** |
| Niepowodzenia | 28 | 15 |
| `std::wstring_view` w `Utility/String.hpp` | 13 | — |
| `using enum` (GCC 11+) | 4 | 4 |
| `OPENLOCO_PLATFORM` nieznana platforma | 4 | 4 |
| `sfl::static_vector` konwersje | 4 | 4 |
| makro `listen` z bsdsocket | 1 | 1 |
| `full path exe retrieval` | 1 | 1 |
| `ALC_HRTF_SOFT` nie zadeklarowane | 1 | — |
| brak `iconv.h` | — | 1 |

Poprzednia wersja tej próby podawała 60/394 i 365/394. Obie liczby były błędne:
brakowało `-fno-char8_t`, które upstream ustawia w CMake, przez co próba
wymyśliła 15 błędów konwersji `char8_t`, których prawdziwy build nie widzi, a
ABIv11 nie miał patcha fmt. Liczby w tabeli pochodzą z próby z wyrównanymi
flagami.

Logi każdego pliku są w `docs/evidence/compile-probe/abiv11/` i `docs/evidence/compile-probe/mainline-v1/`,
zestawienie w `docs/evidence/compile-probe/summary.json`. Skrypt: `scripts/compile-probe.py`,
zależności: `scripts/fetch-deps.sh`.

**Nie wykonano linkowania ani uruchomienia w QEMU.** Te liczby opisują pliki
obiektowe, nie działający program. `366/394` nie znaczy „93% portu gotowe" —
znaczy tylko tyle, że tyle jednostek translacji przechodzi przez kompilator.

## Co wymaga roboty

0. **SDL3 na ABIv11 — zbudowane i uruchomione 2026-09-12.** Statyczna
   biblioteka z listy plików contrib, 187/187 obiektów; okno, streaming
   texture i klawiatura działają na AROS One. Nie zdjęło to pozycji 1: to
   build obok systemu budowania AROS-a, nie `sdl3.library` z contrib.
   Otwarte po tym teście: renderer programowy (wybrany został `opengl`),
   wydajność (6.1 fps przy 320x240 pod TCG) i dźwięk przez AHI.
   Pełny wynik: `docs/evidence/sdl3-abiv11/RESULTS.md`.
1. **SDL3 dla ABIv11 nie istnieje jako build w drzewie.** `contrib/SDL3` to pełny natywny
   backend: video przez `SDL_arosframebuffer`, audio przez AHI, wątki, timer,
   joystick, schowek, messagebox, locale, OpenGL przez `SDL_arosopengl`, plus
   renderer programowy i OpenGL-owy. Jest w drzewie mainline i buduje się jako
   `sdl3.library` przez mmakefile z zależnością od `workbench-libs-mesa-linklib`
   i `development-libiconv`. **Drzewo deadwooda (`~/Work/AROS/aros-src`) nie ma
   contrib w ogóle.** Żaden z dwóch SDK nie ma nagłówków SDL3 — jest tylko SDL1.2
   i SDL2. To jest największa pozycja w całym porcie i dotyczy właśnie celu
   głównego. Do rozstrzygnięcia: wstawić mainline contrib do drzewa ABIv11, czy
   zbudować SDL3 poza systemem budowania AROS-a.
2. **`std::wstring_view` w `Utility/String.hpp:14`** — 13 plików na ABIv11.
   `toUtf8(const std::wstring_view&)` jest helperem Windows; do owarunkowania.
3. **`using enum`** — 4 pliki na obu ABI, `CompanyAi.cpp` i sąsiedzi. Albo
   przepisanie, albo nowszy GCC.
4. **`<execution>` i TBB — nie jedna linia.** Wywołanie jest jedno
   (`src/OpenLoco/src/Viewport.cpp:187`, `std::for_each(std::execution::par, …)`),
   ale trzeba też usunąć albo owarunkować `#include <execution>` w tym pliku
   (linia 26) i zdjąć TBB po stronie CMake: `CMakeLists.txt:76` ustawia
   `HAS_LIBSTDCPP`, `thirdparty/CMakeLists.txt:85-88` szuka wtedy TBB i ostrzega,
   gdy go nie ma, a `src/OpenLoco/CMakeLists.txt:758` dokłada `TBB::tbb` do
   linkowania. Cztery miejsca, nie jedno.
5. **OpenAL.** Na ABIv11 `AudioEngine.cpp` nie zna `ALC_HRTF_SOFT` — SDK ma
   openal-soft 1.19.1 (2018), bez tego rozszerzenia. Albo owarunkować HRTF,
   albo podnieść openal-soft. Na mainline biblioteki nie ma wcale: nagłówki
   `AL/` są, ale `contrib/MultiMedia/libs/OpenAL` nie jest zbudowane.
6. **iconv na mainline.** `iconv.h` nie ma w SDK, przez co
   `src/Utility/src/String.cpp` nie kompiluje się na mainline, a na ABIv11 tak
   (ma `iconv.h` i `libiconv.a`). To nie brak AROS-a, tylko niezbudowany contrib.
7. **Rozpoznanie platformy.** `src/Version/include/OpenLoco/Version.hpp:46`
   kończy się `#error`, bo nie zna `__AROS__`. Gałąź to trzy linie i nadaje się
   do zgłoszenia upstream.
8. **`src/Platform/src/Platform.Posix.cpp`** — `#error "Platform does not support
   full path exe retrieval"`. AROS potrzebuje własnej gałęzi (`PROGDIR:`),
   podobnie ścieżki konfiguracji, które na AROS nie idą przez XDG.
9. **Makro `listen`.** Nagłówki bsdsocket definiują `listen` jako makro, co
   psuje `Network/Socket.h:65` i `Socket.cpp:415`. `#undef` albo zmiana nazwy
   metody; sieć nie jest potrzebna do pierwszego uruchomienia.
10. **`sfl::static_vector`** — 4 pliki na obu ABI, konwersje nieprzechodzące pod
    GCC 10. Lokalne.
11. **Zasoby gry.** OpenLoco wymaga plików z oryginalnego Chris Sawyer's
    Locomotion. Sam ELF nic nie da.

## Rzeczy, które wypadły korzystnie

- **Renderer programowy jest już przewidziany w kodzie.**
  `src/OpenLoco/src/Graphics/SoftwareDrawingEngine.cpp:54` próbuje domyślnego
  renderera, a linia 60 jawnie żąda `"software"` jako fallback. To dokładnie ten
  brak, który w GrafX2 był ryzykiem startu. Tutaj go nie ma.
- **Łatka AROS do SDL3 nakłada się na upstream 3.4.12 bez jednego odrzuconego
  hunka.** Port SDL3 jest utrzymywany: aktualizacja do 3.4.12 i fix builda m68k
  z 2026-07-28.
- **Gra rysuje do bufora programowego i prezentuje go teksturą** — nie potrzebuje
  akceleracji 3D. Wymagania oryginału są z 2004 roku.

## Zalecana kolejność

1. **Minimalne okno SDL3 na ABIv11.** Zbudować SDL3 i uruchomić najprostszy
   program otwierający okno i odbierający zdarzenia. To rozstrzyga największą
   niewiadomą portu i przy okazji pierwszy raz sprawdza wątki w działaniu.
2. Dopiero potem kod gry: `wstring_view`, `using enum`, gałęzie `__AROS__`
   w `Version.hpp` i `Platform.Posix.cpp`, `<execution>`/TBB w trzech miejscach,
   HRTF, makro `listen`, `sfl`.
3. **Pełne linkowanie.** Dopiero ono pokaże, czy w SDK nie ma stubów zamiast
   prawdziwych symboli — kompilacja tego nie rozstrzyga.
4. Uruchomienie w QEMU, osobno na każdym ABI, na zgodnym systemie. Wynik
   raportować z nazwą maszyny.

Perspektywa: **wysoka wykonalność**. Główna niewiadoma to nie kod gry, tylko
SDL3 na ABIv11 i zachowanie wątków w czasie wykonania. Dopóki nie ma linkowania
i uruchomienia, nie ma podstaw do podawania liczby dni.
