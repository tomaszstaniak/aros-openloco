# CMake toolchain file for AROS x86_64 (uses ../AROS/toolchain + ../AROS/sdk)
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(AROS_ROOT "/Volumes/arosmain")
set(CMAKE_C_COMPILER   ${AROS_ROOT}/toolchain-mainline/x86_64-aros-gcc)
set(CMAKE_CXX_COMPILER ${AROS_ROOT}/toolchain-mainline/x86_64-aros-g++)
set(CMAKE_AR           ${AROS_ROOT}/toolchain-mainline/x86_64-aros-ar)
set(CMAKE_RANLIB       ${AROS_ROOT}/toolchain-mainline/x86_64-aros-ranlib)
set(CMAKE_SYSROOT      ${AROS_ROOT}/build/bin/pc-x86_64/AROS/Developer)
set(CMAKE_FIND_ROOT_PATH ${AROS_ROOT}/build/bin/pc-x86_64/AROS/Developer ${CMAKE_CURRENT_LIST_DIR}/deps/prefix)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_C_FLAGS_INIT   "-I${AROS_ROOT}/build/bin/pc-x86_64/AROS/Developer/include")
set(CMAKE_CXX_FLAGS_INIT "-I${AROS_ROOT}/build/bin/pc-x86_64/AROS/Developer/include")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${AROS_ROOT}/build/bin/pc-x86_64/AROS/Developer/lib")
# try_compile MUST link, not just compile. With STATIC_LIBRARY every link test
# passes vacuously, and CMake then believes things that are false: that this
# GCC accepts -pthread (it does not) and that -lpthreads exists (it is
# -lpthread here). Both were discovered as link failures of the real binary.
set(CMAKE_TRY_COMPILE_TARGET_TYPE EXECUTABLE)
set(BUILD_SHARED_LIBS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
set(CMAKE_CXX_COMPILE_OPTIONS_PIC "")
set(CMAKE_C_COMPILE_OPTIONS_PIC "")
set(AROS ON)

# --- PNG / zlib: wskaż archiwa statyczne, nie stuby ------------------------
# libpng.a i libz.a w SDK to link stuby do png.library i z1.library.
# Wariant statyczny daje niezależność od obecności i wersji tych bibliotek na
# maszynie użytkownika. find_package(PNG)/find_package(ZLIB) znajdą stuby, więc podajemy
# ścieżki wprost jako CACHE, zanim ktokolwiek je zawoła.
# Kolejność linkowania: libpng woła zlib, więc png musi poprzedzać z.
set(ZLIB_LIBRARY "${CMAKE_SYSROOT}/lib/libz.static.a" CACHE FILEPATH "AROS: statyczna zlib, nie stub z1.library")
set(ZLIB_INCLUDE_DIR "${CMAKE_SYSROOT}/include" CACHE PATH "")
set(PNG_LIBRARY "${CMAKE_SYSROOT}/lib/libpng_nostdio.a" CACHE FILEPATH "AROS: statyczna libpng bez stdio, nie stub png.library")
set(PNG_PNG_INCLUDE_DIR "${CMAKE_SYSROOT}/include" CACHE PATH "")
# libpng_nostdio nie ma png_init_io(); OpenLoco go nie używa (własne callbacki
# w Gfx/src/PngImage.cpp i Ui/Screenshot.cpp).

# --- SDL3: nasz statyczny build, nie ma go w SDK --------------------------
# scripts/build-sdl3.sh generuje tam SDL3Config.cmake, żeby
# find_package(SDL3 REQUIRED CONFIG) z thirdparty/CMakeLists.txt miał co znaleźć.
set(SDL3_DIR "${CMAKE_CURRENT_LIST_DIR}/../deps/mainline-v1/lib/cmake/SDL3" CACHE PATH "")

# --- OpenAL: SDK nie ma pakietu CMake ani .pc ------------------------------
# scripts/make-cmake-packages.sh generuje go w deps/mainline-v1/lib/cmake/OpenAL.
set(OpenAL_DIR "${CMAKE_CURRENT_LIST_DIR}/../deps/mainline-v1/lib/cmake/OpenAL" CACHE PATH "")

# --- fmt / sfl / yaml-cpp: nasze przypięte i załatane źródła ---------------
# thirdparty/CMakeLists.txt ściąga je przez FetchContent. Bez tego build
# pobiera czyste fmt i wraca problem std::wstring, którego nie ma w naszej
# kopii (patches/dependencies/fmt-11.1.4-aros-nowstring.diff).
# FETCHCONTENT_SOURCE_DIR_<NAZWA> każe CMake użyć katalogu zamiast pobierania.
set(FETCHCONTENT_SOURCE_DIR_FMT "${CMAKE_CURRENT_LIST_DIR}/../deps/mainline-v1/src/fmt" CACHE PATH "")
set(FETCHCONTENT_SOURCE_DIR_SFL "${CMAKE_CURRENT_LIST_DIR}/../deps/mainline-v1/src/sfl" CACHE PATH "")
set(FETCHCONTENT_SOURCE_DIR_YAML-CPP "${CMAKE_CURRENT_LIST_DIR}/../deps/mainline-v1/src/yaml" CACHE PATH "")

# --- wątki: AROS GCC nie zna -pthread -------------------------------------
# Ani gcc, ani g++ nie akceptują tej flagi (weryfikowane 2026-09-13), a
# upstream ustawia THREADS_PREFER_PTHREAD_FLAG ON, więc FindThreads chciałby ją
# dodać. Zaszczepiamy wynik testu na FALSE, żeby FindThreads poszedł ścieżką
# biblioteki i zlinkował -lpthread, która w SDK jest.
set(THREADS_HAVE_PTHREAD_ARG FALSE CACHE INTERNAL "AROS GCC nie zna -pthread")

# --- LTO wyłączone --------------------------------------------------------
# GCC 10.5.0 wywraca się wewnętrznie przy linkowaniu:
#   lto1: internal compiler error: in add_symbol_to_partition_1
# przy mieszaniu obiektów LTO z nie-LTO-wymi bibliotekami SDK i naszym
# statycznym SDL3. To błąd kompilatora, nie kodu gry.
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE OFF CACHE BOOL "GCC 10 LTO ICE na AROS")
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF CACHE BOOL "")

# --- bsdsocket: SocketBase ------------------------------------------------
# Wywołania bsdsocket.library odwołują się do globalnej SocketBase, którą
# definiuje i otwiera autoinit z libnet.a. Bez tego link kończy się jednym
# nierozwiązanym symbolem i wygląda na błąd w kodzie sieciowym.
# Musi trafić na KONIEC linii linkowania, nie na początek: to archiwum
# statyczne, a linker bierze z niego tylko to, czego brakuje w już widzianych
# obiektach. CMAKE_*_STANDARD_LIBRARIES jest doklejane na końcu.
set(CMAKE_CXX_STANDARD_LIBRARIES "-lnet" CACHE STRING "")
set(CMAKE_C_STANDARD_LIBRARIES "-lnet" CACHE STRING "")

# --- PIC wyłączony --------------------------------------------------------
# AROS linkuje statycznie i nie ma GOT-u: obiekty z -fPIC zostawiają
# nierozwiązane _GLOBAL_OFFSET_TABLE_. yaml-cpp włącza PIC własną opcją
# YAML_ENABLE_PIC, więc samo CMAKE_POSITION_INDEPENDENT_CODE nie wystarcza.
set(YAML_ENABLE_PIC OFF CACHE BOOL "AROS: brak GOT, PIC zostawia nierozwiazany symbol")
