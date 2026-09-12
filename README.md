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
`work/`, a utrwalamy je jako łatki w `patches/openloco/`.

Commitujemy tylko do tego repozytorium. Wysłanie czegokolwiek do upstreamu
OpenLoco byłoby osobnym, świadomym krokiem (PR z obsługą AROS) — lokalny
commit nigdy niczego tam nie wysyła.

## Od zera

```sh
scripts/bootstrap.sh                 # upstream/ na przypiętym commicie + work/
scripts/fetch-deps.sh abiv11         # SDL3 (contrib + nasze łatki), fmt, sfl, yaml
scripts/compile-probe.py             # próba kompilacji, oba ABI -> docs/evidence/
scripts/build-sdl3.sh abiv11         # libSDL3_static.a -> deps/abiv11/lib
scripts/build-smoke.sh abiv11        # test SDL3 + std::thread -> build/abiv11/
```

Nazwy ABI (`abiv11`, `mainline-v1`), ścieżki toolchainów i SDK są w jednym
miejscu: `scripts/env.sh`. Można je nadpisać zmiennymi środowiskowymi.

## Stan

Patrz `docs/AROS-ASSESSMENT.md` (ocena, liczby, blokady) i
`docs/evidence/sdl3-abiv11/RESULTS.md` (SDL3 i wątki uruchomione na AROS One).
Otwarte pozycje: `docs/backlog/`.
