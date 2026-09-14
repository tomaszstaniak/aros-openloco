# Backlog — otwarte pozycje

Stan na 2026-09-15. **OpenLoco działa na AROS One (ABIv11):** menu, ekran
tytułowy z animowaną mapą i wczytany scenariusz z interfejsem i zegarem gry.
Dowody: `../evidence/menu-abiv11/RESULTS.md`. 15 łatek gry + łatki zależności.

Kolejność pozycji mniej więcej według wpływu. Każda mówi, co jest niewiadome i
co by ją zamknęło. Pozycje zamknięte zostają dla historii decyzji.

Uwaga o standardzie: `~/Work/AROS-dev/.workspace.json` wskazuje centralny
`project-standards` w wersji **`0.2-proposal`**. Ten projekt nie ma zapisanej
decyzji o udziale (`project.json`), więc backlog zostaje w obecnym formacie.
Migracja do formatu „jedna notatka na zmianę" to osobna, świadoma decyzja.

## Powrót po przerwie — co jest w repo, a co nie

Sprawdzone 2026-09-15. **Kod, łatki, skrypty, toolchainy CMake i dokumentacja
są w tym repozytorium i zacommitowane.** Wszystko w `upstream/`, `work/`,
`deps/`, `build/` odtwarza się skryptami — patrz README, „Od zera".

**Poza repozytorium, a bez tego gra nie ruszy** — tego nie da się odtworzyć
samym `git clone`:

| Co | Gdzie | Dlaczego nie w repo | Jeśli zginie |
|---|---|---|---|
| zasoby oryginalnej gry, 510 MB | `~/Work/AROS/assets-staging/Locomotion/` | chronione prawem autorskim, Twoja kopia gry | skopiować ponownie z instalacji Locomotion |
| obraz dysku z zasobami, 700 MB | `~/Work/AROS/loco-assets.img` | pochodna powyższego | odtworzyć procedurą z `../evidence/menu-abiv11/RESULTS.md` |
| system gościa AROS One | `~/Work/AROS/aros-one-hd.qcow2` | wspólny testbench | poza tym projektem |
| toolchain i SDK ABIv11 | `~/Work/AROS/toolchain`, `~/Work/AROS/sdk` | wspólny testbench; ścieżki w `scripts/env.sh` | poza tym projektem |
| obraz `arosbuild`, 4.9 GB | `~/Work/AROS/aros-build.sparseimage` | wspólny testbench | poza tym projektem |

**Trzy pułapki przy powrocie, każda już raz ugryzła:**

1. **`/Volumes/arosbuild` musi być zamontowany przed konfiguracją CMake** —
   `collect-aros` ma ścieżkę linkera na sztywno. Po restarcie Maca obraz jest
   odmontowany. `hdiutil attach -readonly ~/Work/AROS/aros-build.sparseimage`.
   Bez tego build pada **już na pierwszym teście kompilatora**, z komunikatem
   `is not able to compile a simple test program` i w środku
   `collect-aros: /Volumes/arosbuild/toolchain-core-x86_64/x86_64-aros-ld: No
   such file or directory` — co wygląda na zepsuty toolchain, a jest brakiem
   zamontowanego obrazu. `build-openloco.sh` sprawdza to teraz na starcie i
   mówi wprost, co zamontować.
2. **`shared/loco/openloco.yml` musi wskazywać `Locodata:Locomotion`**, nie
   `RAM:Locomotion`. Plik na hoście był nieaktualny (poprawka wpisana tylko w
   gościu); poprawione 2026-09-15.
3. **vvfat to migawka ze startu QEMU** — pliki do `shared/` kopiuje się
   *przed* `run-aros-loco.sh`, nie po.

Poprawione przy tym audycie: `scripts/run-aros-loco.sh` robił `cd` do własnego
katalogu, czyli do `scripts/`, gdzie nie ma dysku QEMU ani `shared/` — z repo
nie dało się go uruchomić. Teraz rozwiązuje ścieżki w `$AROS_TESTBENCH`
(domyślnie `~/Work/AROS`). README nie wymieniało `build-openloco.sh`,
`make-cmake-packages.sh`, `build-png-smoke.sh` ani uruchomienia w QEMU —
uzupełnione.

### Test powrotu z czystego klona

Wykonany 2026-09-15: `git clone` repozytorium do pustego katalogu i pełna
ścieżka z README, bez korzystania z niczego z roboczego drzewa.

| krok | wynik |
|---|---|
| `bootstrap.sh` | **15 łatek gry nałożonych** z czystego upstreamu |
| `fetch-deps.sh abiv11` | SDL3 + łatki AROS, fmt, sfl, yaml pobrane i załatane |
| `build-sdl3.sh`, `make-cmake-packages.sh` | przeszły |
| `build-openloco.sh` — **pierwsza próba** | **padło na konfiguracji CMake**: `/Volumes/arosbuild` niezamontowany (pułapka 1) |
| `build-openloco.sh` — po zamontowaniu | 442/442, `OpenLoco` 14 217 840 B, **0 nierozwiązanych symboli** |

**Porównanie z roboczym drzewem:**

- źródła gry (`work/`, bez `.git`): **0 różnic**;
- załatane zależności — `SDL3-3.4.12`, `fmt`, `sfl`, `yaml`, `contrib-sdl3`:
  **0 różnic** w każdej. Łatka SDL3 na ukryte okno, robiona najpierw ręcznie w
  `deps/`, jest więc w pliku łatki odwzorowana wiernie;
- binarki różnią się rozmiarem (14 217 840 vs 14 212 752 B) i sekcją `.text`.
  **Zweryfikowane** źródła tej różnicy to zaszyte wejścia środowiska: napis
  wersji (`1339e69` vs `12cdfa3 … on baseline`) i ścieżka projektu (62
  wystąpienia). Że różnica `.text` to wyłącznie przesunięcie przemieszczeń po
  zmianie długości napisów w `.rodata` — **wniosek, nie sprawdzony
  deasemblacją**; przy identycznych źródłach, zależnościach i toolchainie innych
  wejść nie ma.

**Wniosek: do pracy da się wrócić z samego repozytorium** — pod warunkiem, że
istnieją zasoby gry i obraz dysku z tabeli wyżej, a `arosbuild` jest zamontowany.
Uruchomienia w QEMU w tym teście nie powtarzano (poprzednie: `../evidence/menu-abiv11/`).

## 0. ZAMKNIĘTE — okno gry i renderer działają na ABIv11

2026-09-13: okno powstaje, silnik OpenLoco rysuje w nim własną treść.
Blokadą było `SDL_WINDOW_HIDDEN`: backend AROS otwiera okno Intuition dopiero
przy `ShowWindow`, a gra żąda renderera wcześniej. Łatka do SDL3 otwiera okno
systemowe na żądanie. Dowody: `../evidence/g1-run-abiv11/RESULTS.md`.

**Otwarte dalej:** menu i mapa — brakuje zasobów oryginalnej gry, patrz §16.

## 16. ZAMKNIĘTE — menu i mapa działają

2026-09-13: pełne zasoby dostarczone, gra doszła do ekranu tytułowego i do
wczytanego scenariusza z interfejsem i zegarem.
Dowody: `../evidence/menu-abiv11/RESULTS.md`.

Transfer 513 MB rozwiązany obrazem dysku **FAT32 z MBR** podpiętym jako
czwarty dysk IDE — vvfat ma limit FAT16 516 MB, którego nie da się obejść
przez `fat:32:`.

**Pozostały szum — przyczyna potwierdzona 2026-09-15:** na obrazie
`loco-assets.img` leży **647 plików `._*`, z tego 544 w `ObjData/`** (policzone
po zamontowaniu obrazu tylko do odczytu). To pliki widełek zasobów, które macOS
dopisał przy kopiowaniu na FAT32; OpenLoco próbuje je wczytać jako obiekty i
stąd seria `[ERR] Unable to load the object '._...'`. Źródło w
`assets-staging/` jest czyste (0 plików `._*`) — śmieci powstają dopiero przy
zapisie na obraz. Poprawka: `dot_clean /Volumes/LOCODATA` przed odpięciem
obrazu. **Samo usunięcie niezweryfikowane w grze.**

## 17. Wersja widoczna w grze nie jest wersją upstreamu

Ekran tytułowy pokazuje np. `OpenLoco, 1339e69 (1339e69 on baseline)`. To hash
commita **prywatnego repozytorium `work/`**, tworzonego przez `bootstrap.sh` —
inny przy każdym bootstrapie (w teście powrotu: `12cdfa3`). Nie mówi nic o
upstreamie OpenLoco ani o stanie łatek, a wygląda jak identyfikator wersji.

**Zamknie to:** przekazanie do CMake `OPENLOCO_VERSION_TAG`/commita upstreamu
(`UPSTREAM_COMMIT` z `scripts/env.sh`) i liczby łatek, zamiast brania ich z
gita w `work/`. Niska waga — nie wpływa na działanie, tylko na zgłoszenia błędów.

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

## 4. ZAMKNIĘTE — `using enum` pod GCC 10.5

**Zamknięte łatką `04-gcc10-using-enum`** (aliasy `constexpr` w tym samym
zakresie; w `TownManager.cpp` wyjęte przed `switch`). Poniżej pierwotny opis.


`CompanyAi.cpp:3496`, `:3562`, `:3604` i sąsiedzi. To C++20 dodane w GCC 11.
Flagą się tego nie obejdzie.

**Zamknie to:** albo przepisanie tych miejsc jako łatka w `patches/openloco/`,
albo podniesienie toolchaina (AROS ma w crosstools łatki do GCC 16.2.0).
Druga droga jest szersza niż ten port i dotyczy wszystkich projektów C++.

## 5. ZAMKNIĘTE — `std::wstring_view` na ABIv11

**Zamknięte łatką `02-wide-strings-optional`** (helpery Windows pod
`OPENLOCO_HAS_WIDE_STRINGS`). Poniżej pierwotny opis.


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

## 7. ZAMKNIĘTE — pozostałe pozycje kompilacji

**Zamknięte łatkami:** `01-aros-platform-identification` (OPENLOCO_PLATFORM,
ścieżka programu), `03`/`09` (makra bsdsocket), `06`/`10` (OpenAL HRTF i EFX),
`07` (RFC 3493), `08` (`unistd.h`), `11` (IPO/LTO). `iconv.h` dotyczy tylko
mainline. `<execution>`/TBB: build ABIv11 przechodzi. Poniżej pierwotny opis.


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
link OpenLoco — zamknięty (§16).

## 10. CZĘŚCIOWO SPRAWDZONE — współrzędne myszy w SDL3

**Dowód częściowy (2026-09-13, `../evidence/menu-abiv11/`):** w działającej
grze kliknięcie wstrzyknięte w globus menu trafiło i uruchomiło scenariusz —
czyli współrzędne kliknięć mapują się poprawnie w tym przypadku. To jedno
kliknięcie, nie test systematyczny: przeciąganie, prawy przycisk, kółko i
porównanie z `SDL_GetMouseState` nadal niesprawdzone. Poniżej pierwotny opis.


W SDL2 na AROS `ev.button.x/y` dawało (0,0) i obejściem był polling
`SDL_GetMouseState`. Nasz test SDL3 liczył zdarzenia myszy, a nie ich
współrzędne, więc o SDL3 nie wiemy nic.

**Zamknie to:** rozszerzenie testu o odczyt współrzędnych i porównanie zdarzeń
z `SDL_GetMouseState`.

## 11. Strip binarki — nie na pełno

`x86_64-aros-strip` bez flag psuje relokacje `.text`; program umiera w pierwszym
`OpenLibrary()` i wygląda to jak błąd programu. Bezpieczna forma:
`--strip-unneeded --remove-section .comment`. Do zapisania w skrypcie pakującym,
zanim ktoś zoptymalizuje rozmiar 14 MB binarki.

## 12. Ścieżka „zamknij na żądanie" niesprawdzona

W żadnym przebiegu nie było `quit_event`, a ESC w przebiegu 1 nie dał zdarzenia
(program skończył 300 klatek w tej samej chwili). Gadżet zamknięcia okna
nietestowany.


## 13. ZAMKNIĘTE — binarka startuje (zastąpione przez §16)

**Zamknięte:** gra doszła do menu i wczytanego scenariusza — §16. Poniżej
historia pierwszego uruchomienia bez zasobów.


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

## 13a. ZAMKNIĘTE — stara treść: binarka nie była uruchomiona

**Nieaktualne**, zostawione dla historii. Stan bieżący: §16.


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
