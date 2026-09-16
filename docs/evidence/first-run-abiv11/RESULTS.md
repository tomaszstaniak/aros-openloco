# Pierwsze uruchomienie OpenLoco na AROS — wynik

2026-09-13. Maszyna: **AROS One 64-bit (ABIv11)**, QEMU (TCG), `vm.sh one`,
uruchomiona przez tę sesję. Binarka: `build/abiv11/openloco/OpenLoco`,
14 217 528 B, **nieodchudzona** (patrz backlog §11 — pełny strip psuje
relokacje).

## Wynik: program startuje i przechodzi całą ścieżkę wykrywania zasobów

Zasobów oryginalnego Chris Sawyer's Locomotion nie ma na tej maszynie, więc
test kończy się tam, gdzie musi — na braku `Data/g1.DAT`. **To nie jest awaria
portu, tylko brak danych wejściowych**, i sama droga do tego miejsca jest
właśnie tym, co miało zostać sprawdzone.

Log gry (`RAM:ver.log`, zrzut 03):

```
[INF] OpenLoco, 1138d80 (1138d80 on baseline)
[INF] AROS (x86-64)
[INF] Searching for Locomotion install path...
Type your Locomotion path:
```

Konsola:

```
[ERR] Unable to automatically find the Locomotion game folder.
Please provide the location manually.
RAM:loco
[ERR] The selected folder does not contain Data/g1.DAT
```

### Co to potwierdza

| | dowód |
|---|---|
| Program się ładuje i startuje | wraca prompt, żadnego „Illegal address access" |
| 19 baz bibliotek otwiera się | `SysBase`, `DOSBase`, `IntuitionBase`, `GfxBase`, `CyberGfxBase`, `GLBase`, `OpenALBase`, `MUIMasterBase`, `GadToolsBase`, `IconBase`, `IFFParseBase`, `KeymapBase`, `LowLevelBase`, `TimerBase`, `WorkbenchBase`, `CxBase`, `CrtBase`, `StdlibBase`, `MBase` — program doszedł do własnego kodu, więc autoinit przeszedł |
| Konstruktory statyczne C++ | logowanie i `Version::getVersionInfo()` działają przed czymkolwiek innym |
| **Rozpoznanie platformy** | `[INF] AROS (x86-64)` — łatka `01-aros-platform-identification` |
| Logowanie | i na konsolę, i przez przekierowanie do pliku |
| **Okno SDL3 na AROS** | dwa różne komunikaty jako natywne okna Intuition (zrzuty 01 i 02) — backend `SDL_arosmessagebox` |
| Odczyt stdin | `std::getline` przyjął wpisaną ścieżkę |
| `std::filesystem` | poprawnie stwierdził brak `Data/g1.DAT` we wskazanym katalogu |
| Czyste wyjście | powrót do Shella bez zawieszenia i bez śmieci na ekranie |

### Zrzuty

- `01-first-run-messagebox.png` — pierwsze okno: „Unable to
  automatically detect the Locomotion game folder."
- `02-game-path-validation.png` — drugie okno po podaniu ścieżki: „The
  selected folder does not contain Data/g1.DAT…"
- `03-log-and-clean-exit.png` — treść `RAM:ver.log` z `[INF] AROS (x86-64)`
  i powrót do promptu.

## Czego ten test NIE pokazał

- **Menu, mapy, rozgrywki.** Bez `Data/g1.DAT` gra nie dochodzi do inicjalizacji
  wideo — nie powstało okno gry, nie narysowano ani jednej klatki, nie ruszono
  dźwięku. Kroki 2–4 planu (menu, scenariusz, zapis/odczyt) są **nietknięte**.
- **Renderera.** To były okna komunikatów SDL3, nie `SDL_CreateRenderer` ani
  tekstura ekranu gry. O wydajności ten test nie mówi nic.
- **Dźwięku.** `OpenALBase` jest w wymaganiach binarki, ale nic nie zagrało.
- **Sieci.** Niedotknięta.

## Jak podejść do kroków 2–4 (menu, mapa, zapis)

Dwie rzeczy trzeba zrobić **przed** startem maszyny, inaczej próba zacznie się
od diagnozowania niewłaściwych objawów:

1. **Udostępnić cały katalog zainstalowanej gry, nie samo `Data/`.**
   `Data/g1.DAT` zdejmuje tylko pierwszą bramkę; scenariusze i obiekty sięgają
   dalej, a brakujące pliki wyglądałyby potem jak błędy portu.
   Miejsce: `~/Work/AROS/shared/Locomotion/` (osobny katalog — uwaga poniżej).
2. **Skopiować je zanim QEMU wystartuje.** Dysk vvfat to **migawka robiona przy
   starcie maszyny**: pliki dorzucone do `shared/` przy działającym AROS-ie są
   dla gościa niewidoczne i nie pomaga czekanie, tylko restart
   (`../../../../docs/platform/testbench.md`). „Maszyna nadal chodzi" **nie**
   znaczy, że można podjąć test od ręki.

**Nie kładź zasobów Locomotion obok `data/` OpenLoco w jednym katalogu.**
Host jest case-insensitive: `Data/` gry i `data/` OpenLoco zlałyby się w jeden
katalog po stronie macOS. To ta sama własność, przez którą `<graphics/gfx.h>`
trafiał wcześniej w `OpenLoco/Graphics/Gfx.h`. Stąd osobne
`shared/Locomotion/` obok `shared/loco/`.

## Jak powtórzyć

**Nie kopiuj `data/` przez CD** — 168 plików w jednym katalogu wiesza `copy`
na zawsze przy 100% CPU (patrz `../../../../docs/platform/porting-notes.md`).
Użyj dysku vvfat:

### Wariant, który testujemy: wszystko na RAM:

Zarówno gra, jak i zasoby lądują w RAM:, a vvfat służy wyłącznie do
przeniesienia ich do gościa. Powód jest jeden i konkretny: **zapis z gościa na
vvfat cicho psuje pliki po stronie hosta**, a nie wiemy z góry, czy OpenLoco
niczego nie zapisze obok zasobów. RAM: nie ma tego problemu i jest szybszy.
Miejsca starczy — RAM: pokazywał ~1 GB wolnego.

```sh
# NA HOŚCIE, przed startem QEMU:
cp -R build/abiv11/openloco/OpenLoco build/abiv11/openloco/data ~/Work/AROS/shared/loco/
cp -R "<instalacja Locomotion>"/* ~/Work/AROS/shared/Locomotion/
~/Work/AROS/vm.sh start one          # FAT powstaje przy starcie QEMU
```

```
; W GOŚCIU:
makedir RAM:loco
copy "Qemu Vvfat:loco" RAM:loco ALL QUIET
makedir RAM:Locomotion
copy "Qemu Vvfat:Locomotion" RAM:Locomotion ALL QUIET
cd RAM:loco
OpenLoco >RAM:run.log
; gdy zapyta o ścieżkę, podaj:
RAM:Locomotion
```

Program uruchamiany z `RAM:loco`, bo `PROGDIR:` musi być zapisywalny.

### Wariant alternatywny: zasoby zostają na vvfat

Wtedy do RAM: idzie **tylko** OpenLoco, a grze podaje się
`Qemu Vvfat:Locomotion`. Oszczędza kopiowanie kilkudziesięciu MB, ale jest
dobry tylko dopóki gra nic w tym katalogu nie zapisze — a tego jeszcze nie
sprawdziliśmy. **Nie mieszać wariantów:** ścieżka podana grze musi wskazywać
ten wolumin, na który zasoby faktycznie trafiły.
