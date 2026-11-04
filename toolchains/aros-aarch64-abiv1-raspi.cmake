# CMake toolchain file for native AROS on the Raspberry Pi (aarch64, ABIv1).
#
# Compilers are scripts/aros-raspi-cc and -cxx: Clang 20.1.0 of the Pi
# toolchain, with the SDK below and the libc++ of deps/<abi>/cxxrt. Both read
# scripts/env.sh, so AROS_RASPI_TOOLCHAIN and AROS_RASPI_SDK override the
# defaults here and in the wrappers alike.
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(OL_ABI aros-aarch64-abiv1-raspi)
get_filename_component(OL_PORT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(OL_DEPS "${OL_PORT}/deps/${OL_ABI}")
if(DEFINED ENV{AROS_RASPI_TOOLCHAIN})
    set(OL_TC "$ENV{AROS_RASPI_TOOLCHAIN}")
else()
    set(OL_TC "$ENV{HOME}/Work/AROS/toolchains/raspi-aarch64")
endif()
if(DEFINED ENV{AROS_RASPI_SDK})
    set(OL_SDK "$ENV{AROS_RASPI_SDK}")
else()
    get_filename_component(OL_SDK "${OL_PORT}/../local/raspi/sdk-20261029/Developer" ABSOLUTE)
endif()

set(CMAKE_C_COMPILER   ${OL_PORT}/scripts/aros-raspi-cc)
set(CMAKE_CXX_COMPILER ${OL_PORT}/scripts/aros-raspi-cxx)
set(CMAKE_AR           ${OL_TC}/bin/aarch64-aros-ar)
set(CMAKE_RANLIB       ${OL_TC}/bin/aarch64-aros-ranlib)
set(CMAKE_SYSROOT      ${OL_SDK})
set(CMAKE_FIND_ROOT_PATH ${OL_SDK} ${OL_DEPS})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
# The SDK has no iconv and no AL/ headers: deps/<abi>/include holds those of
# scripts/build-iconv.sh and build-openal.sh, deps/<abi>/lib their archives.
set(CMAKE_C_FLAGS_INIT   "-I${OL_SDK}/include -I${OL_DEPS}/include")
set(CMAKE_CXX_FLAGS_INIT "-I${OL_SDK}/include -I${OL_DEPS}/include")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${OL_SDK}/lib -L${OL_DEPS}/lib")
# See mainline-v1.cmake: link tests must link.
set(CMAKE_TRY_COMPILE_TARGET_TYPE EXECUTABLE)
set(BUILD_SHARED_LIBS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
set(CMAKE_CXX_COMPILE_OPTIONS_PIC "")
set(CMAKE_C_COMPILE_OPTIONS_PIC "")
set(AROS ON)

# --- PNG / zlib: the static archives, not the link stubs (as mainline-v1) --
set(ZLIB_LIBRARY "${OL_SDK}/lib/libz.static.a" CACHE FILEPATH "AROS: static zlib, not the z1.library stub")
set(ZLIB_INCLUDE_DIR "${OL_SDK}/include" CACHE PATH "")
set(PNG_LIBRARY "${OL_SDK}/lib/libpng_nostdio.a" CACHE FILEPATH "AROS: static libpng without stdio, not the png.library stub")
set(PNG_PNG_INCLUDE_DIR "${OL_SDK}/include" CACHE PATH "")

# --- SDL3, OpenAL: our static builds, the SDK has neither ------------------
set(SDL3_DIR "${OL_DEPS}/lib/cmake/SDL3" CACHE PATH "")
set(OpenAL_DIR "${OL_DEPS}/lib/cmake/OpenAL" CACHE PATH "")

# --- fmt / sfl / yaml-cpp: pinned and patched sources (as mainline-v1) -----
set(FETCHCONTENT_SOURCE_DIR_FMT "${OL_DEPS}/src/fmt" CACHE PATH "")
set(FETCHCONTENT_SOURCE_DIR_SFL "${OL_DEPS}/src/sfl" CACHE PATH "")
set(FETCHCONTENT_SOURCE_DIR_YAML-CPP "${OL_DEPS}/src/yaml" CACHE PATH "")

# --- threads: -lpthread from the SDK, not -pthread --------------------------
set(THREADS_HAVE_PTHREAD_ARG FALSE CACHE INTERNAL "link the SDK's libpthread")

# --- LTO off: not tried with this toolchain and the SDK's archives ---------
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE OFF CACHE BOOL "")
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF CACHE BOOL "")

# --- PIC off: AROS links statically, no GOT (see mainline-v1.cmake) --------
set(YAML_ENABLE_PIC OFF CACHE BOOL "AROS: no GOT, PIC leaves an unresolved symbol")

# --- no C++20 module scanning: the toolchain has no clang-scan-deps, and
# OpenLoco uses no modules. With Clang, CMake would scan every C++20 source.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
