# SDL3 + std::thread na AROS ABIv11 — wynik uruchomienia

2026-09-12. Maszyna: **AROS One 64-bit (ABIv11)**, QEMU (TCG), `vm.sh one`,
uruchomiona przez tę sesję. Toolchain `~/Work/AROS/toolchain` (GCC 10.5.0),
SDK `~/Work/AROS/sdk`. Nic nie było budowane ani uruchamiane na mainline.

## Co zbudowano

SDL3 3.4.12 jako **statyczna biblioteka**, poza systemem budowania AROS-a:
lista plików czytana wprost z `contrib/SDL3/main/mmakefile.src` (cel
`SDL3-aros-staticlib`, `-DSDL3_AROS_STATIC`), źródła to upstreamowy tarball
z nałożoną łatką `SDL3-3.4.12-aros.diff` z contrib.

**187 / 187 obiektów skompilowało się**, `libSDL3_static.a` 2.6 MB.
Jedna poprawka po drodze: `src/time/unix/SDL_systime.c` włącza `<langinfo.h>`
bezwarunkowo, choć `nl_langinfo()` używa tylko pod `HAVE_NL_LANGINFO`.
ABIv11 nie ma `langinfo.h` w posixc (mainline ma), więc na ABIv11 ten include
jest jedyną rzeczą, która nie przechodzi. Łatka:
`patches/dependencies/sdl3-3.4.12-langinfo-guard.diff`, nadaje się do zgłoszenia do contrib.

Test zlinkował się z `-lSDL3_static -lGL -liconv -lpthread -lm`, 4.3 MB.

## Wynik — dwa przebiegi

```
sdl3-smoke on AROS ABIv11
SDL compiled=3.4.12 linked=3.4.12 revision=SDL-release-3.4.12-0-gf87239e71
THREADS: PASS  [signalled=1 joinable=1 distinct_id=1 value=500500(expect 500500) hw_concurrency=0]
video driver: aros
  available driver 0: aros
  available driver 1: dummy
renderer: opengl
key down: scancode=4 key=97      <- przebieg 2
key down: scancode=5 key=98
key down: scancode=6 key=99
key down: scancode=7 key=100
frames=300 elapsed_ms=49406 key_events=4 mouse_events=1 quit_event=0
fps=6.1
VIDEO: PASS
RESULT: PASS
```

### Wątki C++ działają w runtime — to jest rozstrzygnięte

To był otwarty punkt z poprzedniej oceny i teraz jest zamknięty dowodem, a nie
przesłanką. `std::thread` startuje, `std::mutex` i `std::condition_variable`
przenoszą wynik, `wait_for` budzi się przez predykat (nie przez timeout),
worker ma inny `thread::id` niż główny wątek, a przekazana wartość jest
poprawna. `join()` wraca. Sprawdzone przez libstdc++, nie przez wątki SDL —
te ostatnie nic by o libstdc++ nie mówiły.

Jedyny drobiazg: `std::thread::hardware_concurrency()` zwraca **0**. To legalne
(„nieokreślone"), ale kod, który dzieli przez tę wartość albo tworzy tyle
wątków, dostanie zero. OpenLoco jej nie używa — sprawdzone grepem.

### Okno, renderer i tekstura działają

Okno Intuition otwiera się na ekranie Workbencha, streaming texture
`SDL_PIXELFORMAT_XRGB8888` aktualizuje się co klatkę i jest prezentowana.
Widać animowany gradient (`shots/01-window-rendering.png`). 300 klatek bez
błędu `SDL_UpdateTexture`, czyste zamknięcie, powrót do Shella.

Sterowniki wideo, które SDL3 zgłasza: `aros` i `dummy`. Wybrany: `aros`.

### Klawiatura działa, mysz częściowo

Przebieg 2: cztery naciśnięcia (a/b/c/d) doszły z poprawnymi scancode'ami
(SDL_SCANCODE_A=4) i keycode'ami (97='a'). `mouse_events=1` — kursor nie był
ruszany celowo, więc to tylko tyle, że kanał myszy nie jest martwy; realnego
testu przeciągania i przycisków nie było.

W przebiegu 1 `key_events=0` mimo wysłanego ESC. Program skończył wtedy 300
klatek w tej samej chwili, więc ESC najpewniej trafił po ostatnim
`SDL_PollEvent`. **Nie traktuję tego jako dowodu, że ESC działa ani że nie
działa** — ścieżka „zamknij na żądanie" pozostaje niesprawdzona, tak samo jak
gadżet zamknięcia okna (`quit_event=0` w obu przebiegach).

## Czego ten test NIE pokazał

- **Renderera programowego.** Wybrany został `opengl` i `setenv
  SDL_RENDER_DRIVER software` w Shellu tego nie zmienił — w drugim przebiegu
  nadal `renderer: opengl`. Albo AROS-owy `setenv` nie dociera do `getenv()`
  posixc, albo SDL3 czyta ten hint inaczej. Ścieżka programowa, czyli ta,
  którą OpenLoco ma jako fallback, **nie została uruchomiona ani razu**.
  Do wymuszenia przez `SDL_SetHint()` w kodzie przy następnym podejściu.
- **Wydajności.** 6.1 fps przy 320x240. To pomiar **pod QEMU/TCG**, przy
  OpenGL-owym rendererze idącym prawdopodobnie przez programową Mesę, i
  zawiera mój własny narzut: test generuje 76 800 pikseli na klatkę w C++.
  Nie jest to liczba o sprzęcie ani o samym SDL3. OpenLoco chodzi w wyższej
  rozdzielczości i potrzebuje wielokrotnie więcej — **wydajność jest teraz
  główną otwartą pozycją** i wymaga pomiaru na realnej maszynie oraz
  porównania obu rendererów.
- **Dźwięku.** `SDL_INIT_AUDIO` nie było w ogóle. Backend AHI niesprawdzony.
- **Sposobu, w jaki port będzie linkowany naprawdę.** To jest statyczna
  biblioteka zbudowana obok systemu budowania AROS-a. Docelowo powinna być
  `sdl3.library` z contrib, zbudowana w drzewie ABIv11 — co nadal wymaga
  rozwiązania sprawy braku contrib w drzewie deadwooda.

## Jak powtórzyć

```sh
scripts/bootstrap.sh && scripts/fetch-deps.sh abiv11
scripts/build-sdl3.sh abiv11     # -> deps/abiv11/lib/libSDL3_static.a
scripts/build-smoke.sh abiv11    # -> build/abiv11/sdl3-smoke
# potem: vm.sh start one, push.sh z DEPLOY=, copy AMIDEV:sdl3smoke RAM:, uruchom
```

Program pisze wynik do `PROGDIR:sdl3-smoke.log`, nie na konsolę — na wspólnym
testbenchu Shell może zawierać wyjście innej sesji, a screendump nie powie
czyje. Log powyżej odczytany przez `type` w Shellu, który ta sesja sama
otworzyła, na maszynie, którą ta sesja sama uruchomiła.
