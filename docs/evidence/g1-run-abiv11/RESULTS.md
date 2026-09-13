# OpenLoco z dostarczonym g1.DAT — ABIv11

Maszyna: AROS One x86_64 ABIv11, QEMU TCG, `one`. Binarka nieodchudzona,
uruchamiana z `RAM:loco`, zasoby w `RAM:Locomotion`.

---

## Przebieg 1 (2026-09-13, sesja `codex-root-20260913T2031`)

Start przeszedł poza walidację brakującego `g1.DAT`, ale zakończył się:

```
[ERR] Warning: file /home/.config/OpenLoco/objects could not be found
[ERR] Unable to create software renderer: No system window
```

W logu widniała też podejrzana ścieżka `RAM Disk:loco/RAM:Locomotion`.
Dowody: `01-renderer-failure.png`, `02-run-log.png`.

---

## Przebieg 2 (2026-09-13, wieczór) — pięć blokerów zdjętych

### Co naprawiono i dlaczego

**1. „No system window" — to nie był brak akceleracji.**
Backend AROS w SDL3 otwiera okno Intuition dopiero w `AROS_ShowWindow_Internal()`,
więc okno utworzone z `SDL_WINDOW_HIDDEN` nie ma jeszcze `data->win`.
OpenLoco tworzy okno **ukryte** (`SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN`,
`Ui.cpp:224`), buduje renderer, i dopiero potem woła `SDL_ShowWindow()`
(`Ui.cpp:286`). Na AROS ta kolejność była niewykonalna.
Test `tests/sdl3-smoke/` tego nie wykrył, bo tworzy okno **widoczne** — stąd
wcześniejsze „SDL3 działa" i jednoczesna awaria gry.
Łatka: `patches/dependencies/sdl3-3.4.12-aros-hidden-window-framebuffer.diff`
(okno systemowe otwierane na żądanie). Nadaje się do zgłoszenia do contrib.

**2. `/home/.config/OpenLoco`.** `getpwuid()` na AROS zwraca `/home`, XDG nie
istnieje. Łatka 12.

**3. `RAM Disk:loco/RAM:Locomotion`.** `fs::canonical()` uznaje za absolutną
tylko ścieżkę z wiodącym `/`, więc ścieżka AmigaDOS szła jako względna i była
doklejana do katalogu roboczego. Ścieżki z wolumenem albo assignem przed
pierwszym ukośnikiem przepuszczamy bez zmian. Łatka 12.

**4. `cannot create directories`.** Dwa razy: najpierw literalne
`PROGDIR:OpenLoco/logs` (dla `std::filesystem` `':'` to zwykły znak, nie
separator wolumenu), potem kolizja katalogu `OpenLoco` z plikiem wykonywalnym o
tej samej nazwie („Not a directory"). Katalogiem użytkownika jest teraz sam
katalog programu. Łatki 13 i 14.

**5. „Another instance of OpenLoco is already running".** `fcntl(F_SETLK)` na
AROS nie istnieje. Ochrona wyłączona **świadomie**: odpowiednik z AmigaDOS
trzeba by zdejmować przy wyjściu, a zostawiony po awarii blokowałby każde
kolejne uruchomienie. Skutek zapisany w łatce: dwie instancje mogą sobie
nadpisać zapisy. Łatka 15.

### Co osiągnięto

**Okno gry powstaje i silnik OpenLoco w nim rysuje.**
`05-okno-gry-utworzone.png` — natywne okno Intuition o tytule „OpenLoco".
`03-pierwsza-klatka-silnika.png` — gra rysuje własną treść przez swój
programowy renderer w teksturze SDL3. To pierwsza klatka wyrenderowana przez
silnik gry na AROS.

**Menu ani mapy nie osiągnięto.**

### Bloker: brakujące zasoby oryginalnej gry

W `~/Work/AROS/shared/Locomotion/` jest **wyłącznie `g1.DAT`** (2 526 360 B)
i `README.txt`. Po utworzeniu pustych `Scenarios/` i `ObjData/` (co zdjęło
wyjątek `directory iterator cannot open directory`) start zatrzymuje się na:

```
Exception 'Failed to open 'RAM:Locomotion/Data/title.dat' for writing',
thrown at 'FileStream' - src/Core/src/FileStream.cpp:84
```

Dowód: `04-brak-title-dat.png`.

Uwaga do komunikatu: „for writing" jest mylące i pochodzi z upstreamu —
`FileStream.cpp:83` rzuca ten sam tekst przy każdym nieudanym otwarciu, także
do odczytu (jest tam `// TODO: Make this work like fstream`). Plik po prostu
nie istnieje.

**Czego brakuje, wprost z `Environment.cpp:310-400`:**

| Zasób | Do czego |
|---|---|
| `Data/title.dat` | sekwencja ekranu tytułowego — **blokuje teraz** |
| `ObjData/` (zawartość) | obiekty bazowe gry; pusty katalog nie wystarcza |
| `Scenarios/` (zawartość) | scenariusze do wczytania mapy |
| `Data/CSS1.DAT`…`CSS5.DAT` | dźwięk |
| `Data/20s1-6`, `40s1-3`, `50s1-3`, `60s1-3`, `70s1-3`, `80s1-4`, `90s1-2`.DAT | muzyka |
| `Data/KANJI.DAT`, `Chrysanthemum.DAT`, `Eugenia.DAT`, `Rag1-3.DAT` | czcionki i muzyka |
| `Data/TUT800_1-3.DAT`, `TUT1024_1-3.DAT` | samouczek |

Czyli: **potrzebny jest cały katalog zainstalowanej gry**, nie pojedyncze
pliki. Kolejne uruchomienia będą wskazywać następne braki po jednym, bo gra
przerywa na pierwszym.

### Obserwacja uboczna, warta zapamiętania

Gdy OpenLoco kończy się wyjątkiem, jego okno zostaje na ekranie i **blokuje
wejście Intuition** — kliknięcia w Shell przestają działać, ekran nie odświeża
się. Jedynym wyjściem było zatrzymanie maszyny. Przy kolejnych próbach
uruchamiać grę przez `run >RAM:log OpenLoco`, żeby Shell pozostał wolny, i
liczyć się z restartem po awarii.

### Jak powtórzyć

Ścieżkę instalacji można wstawić z góry, zamiast wpisywać ją ręcznie —
`RAM:loco/openloco.yml`:

```yaml
loco_install_path: RAM:Locomotion
```

Reszta procedury: `first-run-abiv11/RESULTS.md`.
