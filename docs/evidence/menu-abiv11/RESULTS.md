# OpenLoco na AROS: menu i działająca mapa — ABIv11

2026-09-13, 22:31. Maszyna: **AROS One 64-bit (ABIv11)**, QEMU TCG, `one`,
`GFX=std`, uruchomiona przez tę sesję. Binarka nieodchudzona, 16 łatek,
`RAM:loco`. Zasoby oryginalnej gry: dysk `Locodata:`.

## Wynik: gra działa

| dowód | co pokazuje |
|---|---|
| `01-menu-and-title-map.png` | ekran tytułowy Locomotion z wyrenderowaną mapą demonstracyjną, globusy menu, „AROS (x86-64)" w rogu |
| `02-title-map-animating.png` | ten sam ekran po chwili — **inny fragment mapy**, czyli pętla renderowania chodzi, a nie stoi na jednej klatce |
| `03-scenario-loaded-game-map.png` | **wczytany scenariusz**: mapa Wielkiej Brytanii z nazwami miast, pasek narzędzi, okno „New Company" z właścicielem, £26 500, zegar gry „7th January 1930" z przyciskami tempa |

Trzeci zrzut jest właściwym kamieniem milowym: to nie ekran tytułowy, tylko
uruchomiona rozgrywka z interfejsem i zegarem.

## Jak rozwiązano transfer 513 MB

**Problem:** całe `shared/` przekraczało limit vvfat —
`Directory does not fit in FAT16 (capacity 516.06 MB)`. `fat:32:` nie pomaga
(QEMU i tak buduje FAT16), a drugi dysk `fat:` bez `rw:` kończył się
`Block node is read-only`.

**Rozwiązanie: prawdziwy obraz dysku zamiast vvfat.**

```sh
dd if=/dev/zero of=~/Work/AROS/loco-assets.img bs=1m count=700
hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage loco-assets.img
diskutil partitionDisk /dev/diskN MBR MS-DOS LOCODATA 100%
cp -R <zasoby> /Volumes/LOCODATA/Locomotion
hdiutil detach /dev/diskN
```

Obraz ma tablicę MBR i jedną partycję **FAT32**, więc limit FAT16 nie
obowiązuje. AROS montuje go jako wolumin `Locodata:` (`info`: 700.0M, 514.1M
zajęte, FAT32).

Podpięty jako **czwarty dysk IDE**, na wolnym `index=3`:

```
-drive file=loco-assets.img,format=raw,if=ide,index=3
```

`index=2` należy do CD-ROM-u — tymczasowy skrypt `/tmp/openloco-one-fat32.sh`
wstawiał tam drugi dysk vvfat i dlatego nie mógł zadziałać.

**Wspólny `run-aros.sh` nie został zmieniony.** Powstała osobna kopia
`~/Work/AROS/run-aros-loco.sh`, która tylko **dokłada** dysk.

### Podział, zgodnie z założeniem

- `RAM:loco` — OpenLoco, jego `data/`, konfiguracja, logi i zapisy (zapisywalne)
- `Locodata:Locomotion` — oryginalne `Data/`, `ObjData/`, `Scenarios/` (tylko czytane)

**Odstępstwo od „docelowo wszystko w RAM:", świadome:** zasoby zostają na
dysku FAT32 zamiast lądować w RAM:. Powody: 513 MB w RAM-dysku o pojemności
~1003 MB zostawiłoby grze mało miejsca na 2 GB maszynie, a kopiowanie tego pod
TCG trwałoby wiele minut przy każdym uruchomieniu. Zakaz z instrukcji dotyczył
**zapisu z gościa na vvfat** — tu nie ma ani vvfat, ani zapisu: gra tylko
czyta z `Locodata:`, a wszystko co pisze idzie do `RAM:loco`.

Ścieżkę wskazuje `RAM:loco/openloco.yml`:

```yaml
loco_install_path: Locodata:Locomotion
```

dzięki czemu gra nie pyta o nią interaktywnie.

## Znany szum w logu — spowodowany moim transferem

```
[ERR] Unable to load the object '._Mac...', can't add to index
[ERR] Data c... (wielokrotnie)
```

macOS zapisał na FAT32 pliki widełek zasobów `._*` obok każdego obiektu, a
OpenLoco próbuje je wczytać jako obiekty. **Nie blokuje to gry** — menu,
scenariusz i mapa działają — ale zaśmieca log i indeks obiektów.

Poprawka (host, przy odmontowanym obrazie): usunąć `._*` i `.DS_Store` z
woluminu, np. `dot_clean /Volumes/LOCODATA` przed odpięciem.
**Niezweryfikowane** — zrzuty powstały przed tą poprawką.

## Czego ten wynik nie pokazuje

- **Wydajności.** Nie mierzona. Pod TCG gra reaguje, ekran tytułowy animuje
  się, scenariusz się wczytuje — ale liczby fps nie ma i nie należy jej
  zgadywać z opóźnień zrzutów.
- **Rozgrywki dłuższej niż kilkadziesiąt sekund**, budowania, zapisu i
  ponownego wczytania stanu.
- **Dźwięku.** `OpenALBase` jest w wymaganiach binarki, ale nic nie grało i
  QEMU startuje bez sterownika audio hosta.
- **Mainline v1.** Wszystko powyższe dotyczy wyłącznie ABIv11.
