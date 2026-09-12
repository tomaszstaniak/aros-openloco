# aros-openloco — reguły projektu

Wspólne zasady są w `../AGENTS.md` i obowiązują tu w całości. Poniżej tylko to,
co specyficzne dla tego portu.

## Cel i priorytet

**ABIv11 jest celem głównym, mainline v1 drugim.** Wynik z jednego ABI nie jest
wynikiem z drugiego — te dwa systemy mają różne libstdc++, różne SDK i różną
zawartość posixc, i już raz różniły się o 300 plików. Każdy raport musi mówić,
z którego ABI pochodzi.

## Gdzie co leży

- `upstream/OpenLoco` — **nigdy nie edytuj.** Jeśli `git status` tam nie jest
  czysty, to jest błąd, nie stan pracy. `scripts/bootstrap.sh` to sprawdza.
- `work/OpenLoco` — tu się edytuje. Ma prywatne repo Git, ale to **nie jest
  historia portu**: jego jedyne zadanie to odpowiadać, co jest zmienione i
  jeszcze niezapisane. Nie commituj tam ręcznie.
- Każda zmiana w kodzie gry, która ma zostać, ląduje jako łatka:
  `scripts/save-patch.sh <nazwa> "po co"`. Zmiana żyjąca tylko w `work/` nie
  jest zapisana — ale nie jest też cicho kasowana: `bootstrap.sh --reset`
  odmawia, dopóki `git -C work/OpenLoco status` nie jest czysty.
- Łatki zależności (`patches/dependencies/`) tak samo: w nagłówku musi być
  powód i zakres, bo za pół roku nikt nie odtworzy, czemu fmt jest ruszony.

## Próby kompilacji

Flagi odwzorowują `cmake/OpenLocoCommon.cmake` z upstreamu. Odstępstwo musi być
jawne i skomentowane w skrypcie. Probe z innymi flagami zmyśla błędy, których
prawdziwy build nie widzi — zdarzyło się to z `-fno-char8_t` i zawyżyło liczbę
„poprawek do zrobienia" o 15 plików.

Liczba w stylu „366/394" jest zdaniem o jednostkach translacji. Nie jest
procentem gotowości portu, nie jest dowodem na linkowanie i nie jest dowodem na
działanie. Tak to opisuj.

## Kolejność dowodów w tym porcie

1. źródła istnieją w contrib →
2. biblioteka się kompiluje →
3. jest zainstalowana w konkretnym SDK →
4. program się linkuje →
5. działa na wskazanej maszynie.

Nie przeskakuj stopni w opisie. SDL3 na ABIv11 jest dziś na stopniu 5, ale jako
statyczny build obok systemu budowania AROS-a — nie jako `sdl3.library` z
contrib, i to trzeba mówić za każdym razem.

## Uruchamianie na maszynach

Testbench jest wspólny — zasady w `../docs/platform/testbench.md`. ABIv11 to
maszyna `one`. Programy testowe piszą wynik do pliku (`PROGDIR:*.log`), nie na
konsolę, bo Shell może zawierać wyjście innej sesji.
