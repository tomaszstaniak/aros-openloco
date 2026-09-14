# aros-openloco

Port OpenLoco (reimplementacja Chris Sawyer's Locomotion) na natywne AROS
x86_64. **Cel główny: ABIv11** (AROS One). Drugi target: mainline v1.

To repozytorium zawiera wyłącznie nasze rzeczy — dokumentację, skrypty,
łatki i testy. Kod gry nie jest tu wersjonowany: pobiera go skrypt, na
przypiętym commicie.

## Układ

```
docs/          dokumentacja, dowody i backlog
  AROS-ASSESSMENT.md   ocena wykonalności portu
  evidence/            logi, wyniki i zrzuty, do których odwołuje się dokumentacja
  backlog/             otwarte pytania i następne zadania
  plans/               plany dłuższych zmian
scripts/       bootstrap, zależności, próby, buildy
toolchains/    pliki toolchainów CMake, jeden na ABI
patches/
  openloco/            nasze zmiany w kodzie gry (nakładane na work/)
  dependencies/        łatki zależności, z uzasadnieniem w nagłówku
tests/         nasz kod testowy (nie kod gry)
upstream/      czysty checkout przypiętego commita — read-only, poza Gitem
work/          kopia robocza z nałożonymi łatkami — poza Gitem
build/<abi>/   wyniki kompilacji — poza Gitem
deps/<abi>/    zależności zewnętrzne — poza Gitem
```

`upstream/` jest referencją i nigdy go nie edytujemy — dzięki temu w każdej
chwili wiadomo, co jest nasze, a co gry. Zmiany w kodzie gry powstają w
`work/`, a utrwalamy je jako łatki:

```sh
scripts/save-patch.sh <nazwa> "po co ta łatka"
```

`work/` ma własne, prywatne repozytorium Git, którego pierwszy commit to
upstream + wszystkie łatki. To nie jest historia portu — to mechanizm, dzięki
któremu `git -C work/OpenLoco status` odpowiada dokładnie na jedno pytanie: co
zmieniłem i jeszcze nie zapisałem jako łatki. **`bootstrap.sh --reset` odmówi
skasowania `work/`, jeśli są tam niezapisane zmiany**; dopiero `--force` je
wyrzuci.

Commitujemy tylko do tego repozytorium. Wysłanie czegokolwiek do upstreamu
OpenLoco byłoby osobnym, świadomym krokiem (PR z obsługą AROS) — lokalny
commit nigdy niczego tam nie wysyła.

## Od zera — pełna ścieżka do działającej gry

Po dłuższej przerwie **zacznij od `docs/backlog/open-questions.md` §„Powrót po
przerwie"** — tam jest lista rzeczy spoza tego repozytorium, bez których poniższe
kroki nie zadziałają.

```sh
# 0. warunki wstępne (poza repo) — patrz backlog, "Powrót po przerwie"
hdiutil attach -readonly ~/Work/AROS/aros-build.sparseimage   # collect-aros tego wymaga

# 1. źródła i zależności
scripts/bootstrap.sh                 # upstream/ na przypiętym commicie + work/ z łatkami
scripts/fetch-deps.sh abiv11         # SDL3 (contrib + nasze łatki), fmt, sfl, yaml

# 2. biblioteki i pakiety CMake, których SDK nie ma
scripts/build-sdl3.sh abiv11         # libSDL3_static.a + SDL3Config.cmake -> deps/abiv11
scripts/make-cmake-packages.sh abiv11  # OpenALConfig.cmake -> deps/abiv11

# 3. gra
scripts/build-openloco.sh abiv11     # -> build/abiv11/openloco/OpenLoco (~14 MB, NIE stripować)

# opcjonalnie: testy platformy
scripts/compile-probe.py             # próba kompilacji, oba ABI -> docs/evidence/
scripts/build-smoke.sh abiv11        # SDL3 + std::thread
scripts/build-png-smoke.sh abiv11    # PNG/zlib bez stubów
```

### Uruchomienie na AROS One

```sh
cp build/abiv11/openloco/OpenLoco ~/Work/AROS/shared/loco/    # przed startem QEMU
cp -R build/abiv11/openloco/data  ~/Work/AROS/shared/loco/
GFX=std scripts/run-aros-loco.sh     # dokłada loco-assets.img jako 4. dysk IDE
```

W gościu:

```
makedir RAM:loco
copy "Qemu Vvfat:loco" RAM:loco ALL QUIET
cd RAM:loco
run >RAM:run.log OpenLoco
```

`RAM:loco/openloco.yml` musi zawierać `loco_install_path: Locodata:Locomotion`
(kopia z `shared/loco/`). Szczegóły i dowody: `docs/evidence/menu-abiv11/RESULTS.md`.

Nazwy ABI (`abiv11`, `mainline-v1`), ścieżki toolchainów i SDK są w jednym
miejscu: `scripts/env.sh`. Można je nadpisać zmiennymi środowiskowymi.

## Stan

Patrz `docs/AROS-ASSESSMENT.md` (ocena, liczby, blokady) i
`docs/evidence/sdl3-abiv11/RESULTS.md` (SDL3 i wątki uruchomione na AROS One).
Otwarte pozycje: `docs/backlog/`.
