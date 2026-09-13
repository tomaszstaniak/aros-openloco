# CMake toolchain file for AROS x86_64 (uses ../AROS/toolchain + ../AROS/sdk)
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(AROS_ROOT "~/Work/AROS")
set(CMAKE_C_COMPILER   ${AROS_ROOT}/toolchain/x86_64-aros-gcc)
set(CMAKE_CXX_COMPILER ${AROS_ROOT}/toolchain/x86_64-aros-g++)
set(CMAKE_AR           ${AROS_ROOT}/toolchain/x86_64-aros-ar)
set(CMAKE_RANLIB       ${AROS_ROOT}/toolchain/x86_64-aros-ranlib)
set(CMAKE_SYSROOT      ${AROS_ROOT}/sdk)
set(CMAKE_FIND_ROOT_PATH ${AROS_ROOT}/sdk ${CMAKE_CURRENT_LIST_DIR}/deps/prefix)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_C_FLAGS_INIT   "-I${AROS_ROOT}/sdk/include")
set(CMAKE_CXX_FLAGS_INIT "-I${AROS_ROOT}/sdk/include")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${AROS_ROOT}/sdk/lib")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
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
