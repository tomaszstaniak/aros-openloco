# CMake toolchain file for AROS x86_64 (uses ../AROS/toolchain + ../AROS/sdk)
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
# The testbench holding toolchain/ and sdk/: $AROS_TESTBENCH, else ~/Work/AROS.
if(DEFINED ENV{AROS_TESTBENCH})
    set(AROS_ROOT "$ENV{AROS_TESTBENCH}")
else()
    set(AROS_ROOT "$ENV{HOME}/Work/AROS")
endif()
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
# No -ffile-prefix-map, although __FILE__ then carries the checkout's absolute
# path: upstream's SourceLocation strips OPENLOCO_PROJECT_PATH from __FILE__
# with substr(), and a mapped (shorter) __FILE__ made every save throw
# "basic_string_view::substr: __pos ... > __size". Build releases from a
# checkout whose path carries nothing personal instead.
set(CMAKE_C_FLAGS_INIT   "-I${AROS_ROOT}/sdk/include")
set(CMAKE_CXX_FLAGS_INIT "-I${AROS_ROOT}/sdk/include")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${AROS_ROOT}/sdk/lib")
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

# --- PNG / zlib: point at the static archives, not the stubs ---------------
# libpng.a and libz.a in the SDK are link stubs into png.library and z1.library.
# The static variant makes us independent of whether those libraries are present
# on the user's machine and of their version. find_package(PNG)/find_package(ZLIB)
# would find the stubs, so we set the paths explicitly as CACHE entries before
# anyone calls them.
# Link order: libpng calls into zlib, so png must precede z.
set(ZLIB_LIBRARY "${CMAKE_SYSROOT}/lib/libz.static.a" CACHE FILEPATH "AROS: static zlib, not the z1.library stub")
set(ZLIB_INCLUDE_DIR "${CMAKE_SYSROOT}/include" CACHE PATH "")
set(PNG_LIBRARY "${CMAKE_SYSROOT}/lib/libpng_nostdio.a" CACHE FILEPATH "AROS: static libpng without stdio, not the png.library stub")
set(PNG_PNG_INCLUDE_DIR "${CMAKE_SYSROOT}/include" CACHE PATH "")
# libpng_nostdio has no png_init_io(); OpenLoco does not use it (it installs its
# own callbacks in Gfx/src/PngImage.cpp and Ui/Screenshot.cpp).

# --- SDL3: our own static build, the SDK has none --------------------------
# scripts/build-sdl3.sh generates SDL3Config.cmake there so that
# find_package(SDL3 REQUIRED CONFIG) from thirdparty/CMakeLists.txt finds something.
set(SDL3_DIR "${CMAKE_CURRENT_LIST_DIR}/../deps/abiv11/lib/cmake/SDL3" CACHE PATH "")

# --- OpenAL: the SDK ships neither a CMake package nor a .pc file ----------
# scripts/make-cmake-packages.sh generates one in deps/abiv11/lib/cmake/OpenAL.
set(OpenAL_DIR "${CMAKE_CURRENT_LIST_DIR}/../deps/abiv11/lib/cmake/OpenAL" CACHE PATH "")

# --- fmt / sfl / yaml-cpp: our pinned and patched sources ------------------
# thirdparty/CMakeLists.txt pulls them in through FetchContent. Without this the
# build downloads a pristine fmt and the std::wstring problem comes back - the
# one our copy does not have (patches/dependencies/fmt-11.1.4-aros-nowstring.diff).
# FETCHCONTENT_SOURCE_DIR_<NAME> tells CMake to use a directory instead of downloading.
set(FETCHCONTENT_SOURCE_DIR_FMT "${CMAKE_CURRENT_LIST_DIR}/../deps/abiv11/src/fmt" CACHE PATH "")
set(FETCHCONTENT_SOURCE_DIR_SFL "${CMAKE_CURRENT_LIST_DIR}/../deps/abiv11/src/sfl" CACHE PATH "")
set(FETCHCONTENT_SOURCE_DIR_YAML-CPP "${CMAKE_CURRENT_LIST_DIR}/../deps/abiv11/src/yaml" CACHE PATH "")

# --- threads: the AROS GCC does not know -pthread --------------------------
# Neither gcc nor g++ accepts the flag (verified 2026-09-13), while upstream sets
# THREADS_PREFER_PTHREAD_FLAG ON, so FindThreads would want to add it. Seed the
# test result as FALSE so FindThreads takes the library path instead and links
# -lpthread, which the SDK does have.
set(THREADS_HAVE_PTHREAD_ARG FALSE CACHE INTERNAL "the AROS GCC does not know -pthread")

# --- LTO disabled ----------------------------------------------------------
# GCC 10.5.0 fails internally while linking:
#   lto1: internal compiler error: in add_symbol_to_partition_1
# when LTO objects meet the non-LTO SDK libraries and our static SDL3. That is a
# compiler bug, not a defect in the game.
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE OFF CACHE BOOL "GCC 10 LTO ICE on AROS")
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF CACHE BOOL "")

# --- bsdsocket: SocketBase, and why libnet.a is NOT linked ----------------
# Calls into bsdsocket.library reference the global SocketBase. libnet.a used to
# be linked to provide it, and that brought two things with it:
#   - autoinit.o, whose constructor opens bsdsocket.library before main() and
#     ends the program with a requester when no TCP/IP stack runs;
#   - strerror.o, a strerror() that shadows the C library's and calls into
#     bsdsocket through SocketBase - fatal as soon as the base is not open.
# Patch 25 defines SocketBase in the game and opens the library on first use,
# so nothing from libnet.a is needed any more. Found on the pool's mainline v1
# machine, which runs no TCP/IP stack: first the requester, and after patch 25
# alone a crash in strerror() called from SDL_IOFromFile().

# --- PIC disabled ----------------------------------------------------------
# AROS links statically and has no GOT: objects built with -fPIC leave
# _GLOBAL_OFFSET_TABLE_ unresolved. yaml-cpp turns PIC on through its own
# YAML_ENABLE_PIC option, so CMAKE_POSITION_INDEPENDENT_CODE alone is not enough.
set(YAML_ENABLE_PIC OFF CACHE BOOL "AROS: no GOT, PIC leaves an unresolved symbol")
