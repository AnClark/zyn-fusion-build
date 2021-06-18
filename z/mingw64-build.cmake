SET(CMAKE_SYSTEM_NAME Windows)


find_package(PkgConfig REQUIRED)

SET(CMAKE_AR x86_64-w64-mingw32-gcc-ar CACHE FILEPATH "Archiver")
SET(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
SET(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
SET(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
SET(CMAKE_LD x86_64-w64-mingw32-gcc)

# This PREFIX_PATH will be specified by -DPREFIX_PATH when invoking cmake
SET(CMAKE_FIND_ROOT_PATH ${PREFIX_PATH})