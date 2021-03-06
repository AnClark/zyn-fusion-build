cmake_minimum_required(VERSION 3.10)
include(ExternalProject)

# Determine processor count
include(ProcessorCount)
ProcessorCount(Ncpu)

option (CROSS_WINDOWS "Enable cross-build for Windows (for Linux host)" OFF)

# Specify toolchain path. I'll pass CMAKE_<BUILD_TOOL_NAME> to Zest.
# Will not affect ZynAddSubFX (it uses dedicated -DCMAKE_TOOLCHAIN_FILE)
# To explicitly specify toolchain for CMake projects, this line must satisfy:
# - Resides in the head of CMakeLists.txt
# - Use type FILEPATH rather than STRING
if (WIN32)
    set (CMAKE_TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/z/mingw64-build.cmake" CACHE FILEPATH "" FORCE)
elseif (CROSS_WINDOWS AND NOT WIN32)
    set (CMAKE_TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/z/windows-build.cmake" CACHE FILEPATH "" FORCE)
endif ()


project(zyn-fusion
  VERSION 3.0.6
  DESCRIPTION "Open source synthesizer"
  LANGUAGES C CXX)

set (PACKAGE_NAME ${PROJECT_NAME})
set (PACKAGE_VERSION "${VERSION}")
set (PACKAGE_STRING "${PACKAGE_NAME} ${PACKAGE_VERSION}")
set (PACKAGE_TARNAME ${PROJECT_NAME})


option (DEMO_MODE "Enable demo mode (silent every 10 minutes)" OFF)

option (PARALLEL_BUILD_DEPS "Enable parallel build on dependencies. 
        Trade-off is that you cannot use `-jn` when invoking `make` in build path.
        DO NOT USE IT WITH NINJA!" ON)

option (PARALLEL_BUILD_ZYNADDSUBFX "Enable parallel build on ZynAddSubFX.
        Trade-off is that you may not compile Zest at the same time via `make -jn`,
        and your terminal output may mess up.
        DO NOT USE IT WITH NINJA!" OFF)

option (PARALLEL_BUILD_ZEST "Enable parallel build on Zest (EXPERIMENTAL).
        Trade-off is that you may not compile ZynAddSubFX and other dependencies
        at the same time via `make -jn`.
        DO NOT USE IT WITH NINJA!" OFF)

if (DEMO_MODE)
    set (BUILD_MODE demo)
else ()
    set (BUILD_MODE release)
endif ()

if (PARALLEL_BUILD_DEPS)
    set (MAKE_MULTIJOB -j${Ncpu})
endif ()

if (PARALLEL_BUILD_ZYNADDSUBFX)
    set (MAKE_MULTIJOB_ZYNADDSUBFX -j${Ncpu})
else ()
    set (MAKE_MULTIJOB_ZYNADDSUBFX -j2)     # Conservative multijob
endif ()


set (ZYN_FUSION_OUT "${CMAKE_CURRENT_BINARY_DIR}/zyn-fusion-${CMAKE_SYSTEM}")
set (DEPS_PATH "${CMAKE_SOURCE_DIR}/deps")
set (DEPS_PREFIX_PATH "${CMAKE_CURRENT_BINARY_DIR}/usr/")
set (DOWNLOAD_PATH "${CMAKE_SOURCE_DIR}/download")
set (PATCH_PATH "${CMAKE_SOURCE_DIR}/patch")

set (ZYNADDSUBFX_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/zynaddsubfx-build")
set (ZYNADDSUBFX_PATH ${DEPS_PATH}/zynaddsubfx-${CMAKE_SYSTEM})
set (ZEST_PATH ${DEPS_PATH}/zest-${CMAKE_SYSTEM})


#
# Build dependencies
#

# Some dependencies won't be built on Linux, as we can use system-provided ones
if (WIN32 OR CROSS_WINDOWS)
    set (EXCLUDE_OR_NOT OFF)
else ()
    set (EXCLUDE_OR_NOT ON)
endif ()

if (WIN32 OR CROSS_WINDOWS)
    set (HOST_ARG --host=x86_64-w64-mingw32)
endif ()

if (WIN32 AND NOT CROSS_WINDOWS)  # fftw3 cannot guess build system type for Msys2. Here's polyfill
    set (BUILD_ARG --build=x86_64-w64-mingw32)
endif ()

# Build FFTW3
ExternalProject_Add (
    fftw3
    DOWNLOAD_DIR ${DOWNLOAD_PATH}
    SOURCE_DIR ${DEPS_PATH}/fftw3

    URL "http://www.fftw.org/fftw-3.3.4.tar.gz"
    URL_MD5 2edab8c06b24feeb3b82bbb3ebf3e7b3
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild

    CONFIGURE_COMMAND ${DEPS_PATH}/fftw3/configure ${BUILD_ARG} ${HOST_ARG} --prefix=${DEPS_PREFIX_PATH} --with-our-malloc --disable-mpi
    BUILD_COMMAND make ${MAKE_MULTIJOB}
    INSTALL_COMMAND make ${MAKE_MULTIJOB} install

    EXCLUDE_FROM_ALL ${EXCLUDE_OR_NOT}
)

# Build liblo
ExternalProject_Add (
    liblo
    DOWNLOAD_DIR ${DOWNLOAD_PATH}
    SOURCE_DIR ${DEPS_PATH}/liblo

    URL "http://downloads.sourceforge.net/liblo/liblo-0.31.tar.gz"
    URL_MD5 14378c1e74c58e777fbb4fcf33ac5315
    #GIT_REPOSITORY "https://github.com/radarsat1/liblo" GIT_SHALLOW
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild

    BUILD_IN_SOURCE ON        # Autotools is not smart enough for using external configure path
    CONFIGURE_COMMAND ${DEPS_PATH}/liblo/autogen.sh ${HOST_ARG} --prefix=${DEPS_PREFIX_PATH} --disable-shared --enable-static --disable-tests --disable-network-tests --disable-examples
    BUILD_COMMAND make ${MAKE_MULTIJOB}
    INSTALL_COMMAND make ${MAKE_MULTIJOB} install

    EXCLUDE_FROM_ALL ${EXCLUDE_OR_NOT}
)

# Build mxml
ExternalProject_Add (
    mxml
    DOWNLOAD_DIR ${DOWNLOAD_PATH}
    SOURCE_DIR ${DEPS_PATH}/mxml

    URL "https://github.com/michaelrsweet/mxml/releases/download/release-2.10/mxml-2.10.tar.gz"
    URL_MD5 8804c961a24500a95690ef287d150abe
    #GIT_REPOSITORY "https://github.com/michaelrsweet/mxml" GIT_SHALLOW
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild

    BUILD_IN_SOURCE ON        # Autotools is not smart enough for using external configure path
    CONFIGURE_COMMAND ${DEPS_PATH}/mxml/configure ${HOST_ARG} --prefix=${DEPS_PREFIX_PATH} --disable-shared --enable-static
    BUILD_COMMAND make ${MAKE_MULTIJOB} libmxml.a
    INSTALL_COMMAND make ${MAKE_MULTIJOB} -i install

    EXCLUDE_FROM_ALL ${EXCLUDE_OR_NOT}
)

# Build PortAudio
ExternalProject_Add (
    portaudio
    DOWNLOAD_DIR ${DOWNLOAD_PATH}
    SOURCE_DIR ${DEPS_PATH}/portaudio
    INSTALL_DIR ${DEPS_PREFIX_PATH}

    URL "http://files.portaudio.com/archives/pa_stable_v190700_20210406.tgz"
    URL_MD5 ad319249932c6794b551d954b8844402
    #GIT_REPOSITORY "https://github.com/PortAudio/portaudio" GIT_SHALLOW
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild

    # Note for configurations:
    # - Consider static library first
    # - Disable WDM Kernel Streaming (already deprecated by Microsoft, will cause error)
    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${DEPS_PREFIX_PATH} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DPA_BUILD_SHARED=1 -DPA_BUILD_STATIC=1 -DPA_USE_WDMKS=0
    BUILD_COMMAND make ${MAKE_MULTIJOB}

    EXCLUDE_FROM_ALL ${EXCLUDE_OR_NOT}
)

# Build zlib
ExternalProject_Add (
    zlib
    DOWNLOAD_DIR ${DOWNLOAD_PATH}
    SOURCE_DIR ${DEPS_PATH}/zlib

    URL "http://downloads.sourceforge.net/libpng/zlib/1.2.7/zlib-1.2.7.tar.gz"
    URL_MD5 60df6a37c56e7c1366cca812414f7b85
    #GIT_REPOSITORY "https://github.com/PortAudio/portaudio" GIT_SHALLOW
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild

    BUILD_IN_SOURCE ON        # Autotools is not smart enough for using external configure path
    CONFIGURE_COMMAND CC=${CMAKE_C_COMPILER} ${DEPS_PATH}/zlib//configure --prefix=${DEPS_PREFIX_PATH} --static
    BUILD_COMMAND make ${MAKE_MULTIJOB}

    EXCLUDE_FROM_ALL ${EXCLUDE_OR_NOT}
)


#
# Build Zyn-Fusion
#

# Build ZynAddSubFX

if (WIN32 OR CROSS_WINDOWS)
    set (ZYNADDSUBFX_DEPENDS fftw3 zlib mxml portaudio liblo)
    set (ZYNADDSUBFX_WIN_CMAKE_ARGS -DPREFIX_PATH=${DEPS_PREFIX_PATH} -DCMAKE_FIND_ROOT_PATH=${DEPS_PREFIX_PATH} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DOssEnable=False -DDefaultOutput=pa)
endif ()

ExternalProject_Add (
    zynaddsubfx
    DEPENDS ${ZYNADDSUBFX_DEPENDS}
    DOWNLOAD_DIR ${DOWNLOAD_PATH}
    SOURCE_DIR ${ZYNADDSUBFX_PATH}
    BINARY_DIR ${ZYNADDSUBFX_BUILD_DIR}

    GIT_REPOSITORY "https://github.com/zynaddsubfx/zynaddsubfx" GIT_SHALLOW
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild

    # Some arguments are not cross-platform
    # - Msys2 only: OssEnable, DefaultOutput
    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${DEPS_PREFIX_PATH} -DDemoMode=${DEMO_MODE} -DGuiModule=zest ${ZYNADDSUBFX_WIN_CMAKE_ARGS}
    BUILD_COMMAND make ${MAKE_MULTIJOB_ZYNADDSUBFX}
    INSTALL_COMMAND ""      # No need to install. We'll copy files manually.
    BUILD_ALWAYS ON         # Always rebuild so that source updates/changes won't be ignored
)

# Build Zest

if (UNIX AND NOT APPLE)
    set (ZEST_MAKE_TARGET linux)
elseif (WIN32 OR CROSS_WINDOWS)
    set (ZEST_MAKE_TARGET windows)
    set (ZEST_COMPILER_FLAGS CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER})
endif ()

ExternalProject_Add (
    zest
    DOWNLOAD_DIR ${DOWNLOAD_PATH}
    SOURCE_DIR ${ZEST_PATH}

    GIT_REPOSITORY "https://github.com/mruby-zest/mruby-zest-build" GIT_SHALLOW
    UPDATE_DISCONNECTED true  # need this to avoid constant rebuild

    BUILD_IN_SOURCE ON
    CONFIGURE_HANDLED_BY_BUILD ON
    CONFIGURE_COMMAND ""
    BUILD_COMMAND make ${ZEST_COMPILER_FLAGS} VERSION=${PACKAGE_VERSION} BUILD_MODE=${BUILD_MODE} ${ZEST_MAKE_TARGET}
    #BUILD_COMMAND make help
    INSTALL_COMMAND ""      # No need to install. We'll copy files manually.
)

ExternalProject_Add_Step (
    zest
    rebuild_fcache
    DEPENDERS build
    DEPENDEES download
    COMMAND rm -f package/qml/*.qml
    COMMAND ruby rebuild-fcache.rb
    WORKING_DIRECTORY ${ZEST_PATH}
    ALWAYS ON
)

if (WIN32 OR CROSS_WINDOWS)
    ExternalProject_Add_Step (
        zest
        mruby_superhack_patch
        DEPENDERS build
        DEPENDEES download
        COMMAND git checkout -- src/backtrace.c
        COMMAND patch -N -p1 -i ${PATCH_PATH}/zest-string-backtraces.patch
        WORKING_DIRECTORY ${ZEST_PATH}/mruby
        ALWAYS OFF
    )
else ()
    ExternalProject_Add_Step (
        zest
        mruby_superhack_patch_revoke
        DEPENDERS build
        DEPENDEES download
        COMMAND git checkout -- src/backtrace.c
        WORKING_DIRECTORY ${ZEST_PATH}/mruby
        ALWAYS OFF
    )
endif ()

ExternalProject_Add_Step (
    zest
    zest_bypass_host_debug
    DEPENDERS build
    DEPENDEES download
    COMMAND git checkout -- build_config.rb
    COMMAND patch -N -p1 -i ${PATCH_PATH}/zest-bypass-host-debug.patch
    WORKING_DIRECTORY ${ZEST_PATH}
    ALWAYS OFF
)

if (PARALLEL_BUILD_ZEST)
    ExternalProject_Add_Step (
        zest
        zest_parallel_build_patch
        DEPENDERS build
        DEPENDEES download
        COMMAND git checkout -- Makefile
        COMMAND sed s/rake/rake\ \-j${Ncpu}/ -i Makefile
        COMMAND sed s/make/make\ \-j${Ncpu}/ -i Makefile
        WORKING_DIRECTORY ${ZEST_PATH}
        ALWAYS OFF
    )
endif ()

if (UNIX AND NOT APPLE)
    ExternalProject_Add_Step (
        zest
        zest_make_pack
        DEPENDEES build
        COMMAND make pack
        WORKING_DIRECTORY ${ZEST_PATH}
        ALWAYS ON
    )
    ExternalProject_Add_Step (
        zest
        zest_remove_package_qml_files
        DEPENDEES zest_make_pack
        COMMAND rm -f package/qml/*.qml
        WORKING_DIRECTORY ${ZEST_PATH}
        ALWAYS ON
    )
endif ()


#
# Install files
#

# Zyn-Fusion binaries
if (WIN32 OR CROSS_WINDOWS)
    set (ZYNADDSUBFX_VST_PATH ${ZYNADDSUBFX_BUILD_DIR}/src/Plugin/ZynAddSubFX/ZynAddSubFX${CMAKE_SHARED_LIBRARY_SUFFIX})
else ()
    set (ZYNADDSUBFX_VST_PATH ${ZYNADDSUBFX_BUILD_DIR}/src/Plugin/ZynAddSubFX/vst/ZynAddSubFX${CMAKE_SHARED_LIBRARY_SUFFIX})
endif ()

install (
    PROGRAMS ${ZEST_PATH}/zest${CMAKE_EXECUTABLE_SUFFIX}
    RENAME zyn-fusion${CMAKE_EXECUTABLE_SUFFIX}
    DESTINATION ${ZYN_FUSION_OUT}
)
install (
    PROGRAMS ${ZYNADDSUBFX_BUILD_DIR}/src/zynaddsubfx${CMAKE_EXECUTABLE_SUFFIX}
    DESTINATION ${ZYN_FUSION_OUT}
)
install (
    FILES
    ${ZEST_PATH}/libzest${CMAKE_SHARED_LIBRARY_SUFFIX}
    ${ZYNADDSUBFX_VST_PATH}
    DESTINATION ${ZYN_FUSION_OUT}
)

# LV2 (Linux only)
if (UNIX AND NOT APPLE)
    # Pre-install target files in order to generate presets
    ExternalProject_Add_Step (
        zynaddsubfx
        preinstall_zynaddsubfx
        DEPENDEES build
        COMMAND make install
        WORKING_DIRECTORY ${ZYNADDSUBFX_BUILD_DIR}
        ALWAYS ON
    )

    # Install preset files
    install (
        DIRECTORY ${DEPS_PREFIX_PATH}/lib/lv2/ZynAddSubFX.lv2presets
        DESTINATION ${ZYN_FUSION_OUT}
    )

    # Install LV2 core
    install (
        DIRECTORY ${ZYNADDSUBFX_BUILD_DIR}/src/Plugin/ZynAddSubFX/lv2
        DESTINATION ${ZYN_FUSION_OUT}/ZynAddSubFX.lv2
    )
endif ()

# Fonts
install (
    FILES
    ${ZEST_PATH}/deps/nanovg/example/entypo.ttf
    ${ZEST_PATH}/deps/nanovg/example/Roboto-Bold.ttf
    ${ZEST_PATH}/deps/nanovg/example/Roboto-Light.ttf
    ${ZEST_PATH}/deps/nanovg/example/Roboto-Regular.ttf
    DESTINATION ${ZYN_FUSION_OUT}/font/
)

# OSC schema
install (
    FILES ${ZEST_PATH}/src/osc-bridge/schema/test.json
    DESTINATION ${ZYN_FUSION_OUT}/schema/
)

# External dependencies
if (WIN32 OR CROSS_WINDOWS)
    if (CROSS_WINDOWS)
        set (MINGW64_LINUX_LIB_PATH /usr/x86_64-w64-mingw32/lib/ /usr/x86_64-w64-mingw32/bin/)
    endif ()

    find_file (
        PTHREAD_LIBRARY
        NAMES libwinpthread-1.dll libwinpthread.dll
        HINTS $ENV{PATH} ${MINGW64_LINUX_LIB_PATH}
    )
    install (
        FILES
        ${DEPS_PREFIX_PATH}/bin/libportaudio.dll
        ${PTHREAD_LIBRARY}
        DESTINATION ${ZYN_FUSION_OUT}
    )
endif ()

# Presets
install (
    DIRECTORY ${ZYNADDSUBFX_PATH}/instruments/banks
    DESTINATION ${ZYN_FUSION_OUT}
)

# Zest MainWindow entrance. Actually it's an empty file.
file(MAKE_DIRECTORY ${ZYN_FUSION_OUT}/qml)
file(TOUCH ${ZYN_FUSION_OUT}/qml/MainWindow.qml)

# Package-related extra files (Linux only)
if (UNIX AND NOT APPLE)
    install (
        PROGRAMS ${ZEST_PATH}/install-linux.sh
        DESTINATION ${ZYN_FUSION_OUT}
    )
    install (
        FILES ${ZEST_PATH}/package-README.txt
        RENAME README.txt
        DESTINATION ${ZYN_FUSION_OUT}
    )
    install (
        FILES ${ZYNADDSUBFX_PATH}/COPYING
        RENAME COPYING.zynaddsubfx
        DESTINATION ${ZYN_FUSION_OUT}
    )
endif ()
