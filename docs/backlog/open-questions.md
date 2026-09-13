# Backlog — otwarte pozycje

Stan na 2026-09-13. **Kompilacja i pełne linkowanie na ABIv11 są zamknięte:**
394/394 jednostek translacji, 442/442 celów ninja, `OpenLoco` 14.2 MB, zero
nierozwiązanych symboli. Odtwarzalne z czystego upstreamu 11 łatkami.
Binarka **nie była jeszcze uruchomiona** — to następna pozycja.

Wcześniejszy stan opisano na 2026-09-12. Kolejność mniej więcej według wpływu na decyzję o porcie.
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

## 9. ZAMKNIĘTE — PNG i zlib linkują się statycznie i działają na AROS One

`libz.a` i `libpng.a` w SDK to link stuby do `z1.library` i `png.library`
(`ar t` na obu SDK, 2026-09-12: `z1_*_stub.o`, ~1.1 KB, `U Z1Base`).

Rozwiązanie: **`-lpng_nostdio -lz.static`**, w tej kolejności. Oba SDK mają te
archiwa; nic nie trzeba budować ze źródeł.

**Kryterium zamknięcia spełnione (2026-09-13, AROS One / ABIv11):**
`tests/png-smoke/` zapisuje PNG przez `png_set_write_fn` i odczytuje przez
`png_set_read_fn` — tak jak robi to gra — round-trip 64x48 RGB piksel w piksel,
kompresja 9216 B → 243 B, libpng 1.6.48, zlib 1.3.1, `RESULT: PASS`.
`nm` na binarce: żadnego `Z1Base` ani `PNGBase`; wymagane bazy to tylko
`SysBase`, `DOSBase`, `IntuitionBase`, `CrtBase`, `StdlibBase`, `MBase`.
Sprawdzenie jest wpięte w `scripts/build-png-smoke.sh` i przerywa build, jeśli
stub kiedykolwiek wróci. Toolchainy CMake wskazują te archiwa wprost, żeby
`find_package(PNG)`/`find_package(ZLIB)` nie wybrało stubów.

**Korekta odziedziczonej notatki:** `z1.library` **jest** obecna na naszym
AROS One 1.3 (`LIBS:z1.library`, 123672 B). Wariant statyczny wybieramy więc
dla niezależności od wersji na maszynie użytkownika, nie dlatego, że biblioteki
brakuje.

**Co zostaje otwarte:** sprawdzono jeden format (RGB8) i jedną ścieżkę we/wy.
Paleta, tRNS, interlace, 16-bit i prawdziwe pliki gry — niesprawdzone. Pełny
link OpenLoco to nadal osobna pozycja.

## 10. Współrzędne myszy w SDL3 niesprawdzone

W SDL2 na AROS `ev.button.x/y` dawało (0,0) i obejściem był polling
`SDL_GetMouseState`. Nasz test SDL3 liczył zdarzenia myszy, a nie ich
współrzędne, więc o SDL3 nie wiemy nic.

**Zamknie to:** rozszerzenie testu o odczyt współrzędnych i porównanie zdarzeń
z `SDL_GetMouseState`.

## 11. Strip binarki — nie na pełno

`x86_64-aros-strip` bez flag psuje relokacje `.text`; program umiera w pierwszym
`OpenLibrary()` i wygląda to jak błąd programu. Bezpieczna forma:
`--strip-unneeded --remove-section .comment`. Do zapisania w skrypcie pakującym,
zanim ktoś zoptymalizuje rozmiar 4 MB binarki.

## 12. Ścieżka „zamknij na żądanie" niesprawdzona

W żadnym przebiegu nie było `quit_event`, a ESC w przebiegu 1 nie dał zdarzenia
(program skończył 300 klatek w tej samej chwili). Gadżet zamknięcia okna
nietestowany.


## 13. CZĘŚCIOWO ZAMKNIĘTE — binarka startuje, ale bez zasobów gry

Uruchomiona 2026-09-13 na AROS One (ABIv11): program się ładuje, otwiera
biblioteki, loguje `[INF] AROS (x86-64)`, pokazuje **dwa natywne okna SDL3**,
czyta stdin, sprawdza ścieżkę przez `std::filesystem` i czysto wychodzi.
Dowody i zrzuty: `../evidence/first-run-abiv11/RESULTS.md`.

**Zostaje otwarte:** menu, mapa, rozgrywka, zapis/odczyt — wszystko to wymaga
`Data/g1.DAT` z oryginalnego Chris Sawyer's Locomotion, którego nie ma na tej
maszynie. Bez tego gra nie dochodzi do inicjalizacji wideo, więc renderer gry
i pierwsza klatka pozostają niesprawdzone.

**Zamknie to:** podłożenie zasobów oryginału i przejście kroków: menu →
scenariusz → mapa → czynności myszą → zapis → ponowne wczytanie → wyjście.
Następny kamień milowy to **menu i pierwsza wyrenderowana mapa** — dopiero to
odpowie, czy główna ścieżka graficzna gry działa.

Dwa warunki przygotowania, oba sprawdzone bólem: udostępnić **cały** katalog
instalacyjny gry (nie samo `Data/`), i zrobić to **przed** startem QEMU, bo
vvfat jest migawką z momentu startu. Szczegóły w
`../evidence/first-run-abiv11/RESULTS.md`.

## 13a. Stara treść: binarka nie była uruchomiona

`build/abiv11/openloco/OpenLoco` linkuje się i nie ma nierozwiązanych symboli,
ale nikt jej nie odpalił. Wymaga bibliotek: `SysBase`, `DOSBase`,
`IntuitionBase`, `GfxBase`, `CyberGfxBase`, `GLBase`, `OpenALBase`,
`MUIMasterBase`, `GadToolsBase`, `IconBase`, `IFFParseBase`, `KeymapBase`,
`LowLevelBase`, `TimerBase`, `WorkbenchBase`, `CxBase`, `CrtBase`,
`StdlibBase`, `MBase`.

**Zamknie to:** uruchomienie na AROS One z zasobami oryginalnej gry.
Uwaga: 14 MB, a pełny strip psuje relokacje — patrz §11.

## 14. Warstwa sieciowa niesprawdzona wobec sieci

`ArosNetCompat.hpp` implementuje getaddrinfo/getnameinfo/inet_ntop dla IPv4
przez gethostbyname/inet_addr. Kompiluje się i linkuje, ale nic tym jeszcze
nigdzie nie połączyło. IPv6 zwraca `EAI_FAMILY` świadomie.

**Zamknie to:** test łączący się z realnym hostem na AROS.

## 15. EFX: pogłos wyłączy się sam, ale to niesprawdzone

`alGetProcAddress` na AROS może zwrócić wskaźniki mimo braku symboli w
archiwum. Kod degraduje się do „brak pogłosu"; czy tak się faktycznie dzieje —
niesprawdzone, bo dźwięku nie uruchamialiśmy.
