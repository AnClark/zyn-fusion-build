# Zyn-Fusion Build System

This is the CMake build system (together with other scripts, if possible) used to generate the Zyn-Fusion packages.

This repository (and only this repository) is licensed under the WTFPL.

---

## Introduction

The new-generation Zyn-Fusion's build system has been totally rewritten in CMake. You can build on both Windows and Linux, and cross-build for Windows is also well supported.

Zyn-Fusion depends on several external projects. By using CMake, managing those dependencies can be much more easier. And you can easily setup build environments in different platforms.

**Built files will be put in directory `./build/` (can be specified when invoking CMake) :**

- `./build/zyn-fusion-<SYSTEM_NAME>`: Ready-to-use Zyn-Fusion files. You can directly use them as you wish, or copy this folder into your DAW's search-path. `SYSTEM_NAME` depends on which target you've built for, for instance, `Windows` or Linux kernel name (same as `uname -s`).

## Build for Linux (native build)

Linux version will link to shared libraries, so you need to install all those necessary dependency libs. Different distributions have different package names.

### a. Install dependencies

```bash
# Arch Linux
sudo pacman -S fftw mxml liblo zlib		# Dependency libs
sudo pacman -S git ruby ruby-rake tar zip wget cmake bison autoconf automake libtool patch	# Build tools

# Debian/Ubuntu
sudo apt install libfftw3-dev libmxml-dev liblo-dev zlib	# Dependency libs
sudo apt install git ruby ruby-dev bison autotools-dev automake libtool premake4 cmake	# Build tools
```

### b. Build Zyn-Fusion

```bash
# Fetch this repository
git clone git://github.com/anclark/zyn-fusion-build.git -b new-generation ~/zyn-fusion-build
cd ~/zyn-fusion-build

# Configure CMake
cmake -S . -B build

# Build and install
cd build
make -j2
make install

# Or directly run `make install` instead. It will build first
make -j2 install
```

> **NOTICE:** You need to run `install-linux.sh` within the built folder to install Zyn-Fusion properly, or it won't run, moreover you'll only see a black window on your host.

## Building for Windows (cross-compile on Linux)

Windows builds will build dependency libs from their source code. Build system will automatically fetch them, then build.

### a. Install build tools

```bash
# Arch Linux
sudo pacman -S git ruby ruby-rake tar zip wget cmake bison autoconf automake libtool patch mingw-w64-gcc

# Debian/Ubuntu
sudo apt install git ruby ruby-dev bison autotools-dev automake libtool patch premake4 cmake mingw-w64-gcc
```

### b. Build Zyn-Fusion

```bash
# Fetch this repository
git clone git://github.com/anclark/zyn-fusion-build.git -b new-generation ~/zyn-fusion-build
cd ~/zyn-fusion-build

# Configure CMake. Here applying CMake var CROSS_WINDOWS enables cross build
cmake -S . -B build -DCROSS_WINDOWS=1

# Build and install
cd build
make -j2
make install

# Or directly run `make install` instead. It will build first
make -j2 install
```

## Building for Windows (cross-compile on WSL2)

If you use Windows, and don't want to install any Linux distribution, WSL2 is the best choice for you. With Microsoft's powerful new-generation engine, building Zyn-Fusion with WSL2 can be as fast as a real Linux distribution.

**All steps are same as above (Building for Windows, cross-compile on Linux).**

### WSL2 dependencies

 Notice that some dependencies will be different from real Linux distribution. Here are two examples:

```bash
# Alpine Linux (use `doas` for root access)
doas apk add git mingw-w64-gcc ruby ruby-rake cmake gcc g++ libtool automake autoconf m4 curl patch

# Ubuntu
sudo apt install git ruby ruby-dev bison autotools-dev automake libtool patch premake4 cmake mingw-w64-gcc
```

I recommend you to try [Alpine Linux](https://www.microsoft.com/store/productId/9P804CRF0395). It's light-weight and fast, and very suitable for WSL2.

## Building for Windows (native build via Msys2)

> **WARNING!**
>
> Due to Msys2 Cygwin's low performance, building process will be **tremendously slow!**
>
> It's highly recommended to cross-build instead.

### a. Preparations

You must install [Msys2](https://www.msys2.org/) first, then **remember running `mingw64.exe` shell in Msys2 install path**.

Or you can also add the following two directories into **the top of** your Windows PATH list, so you can directly run commands in Powershell:

- `<MSYS2_INSTALL_PATH>\mingw64\bin`
- `<MSYS2_INSTALL_PATH>\usr\bin`

The **default MSYS environment** is based on Cygwin, which **won't work**! But you can try cross-build there.

### b. Install dependencies

```bash
pacman -S git ruby gcc bison util-macros automake libtool mingw-w64-x86_64-cmake cmake \
					mingw-w64-x86_64-mruby python3 autoconf zip make wget patch \
					mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-pkg-config \
					mingw-w64-x86_64-gcc-fortran mingw-w64-x86_64-gcc-libgfortran
```

### c. Build

```bash
# Fetch this repository
git clone git://github.com/anclark/zyn-fusion-build.git -b new-generation ~/zyn-fusion-build
cd ~/zyn-fusion-build

# Configure CMake. Only MSYS Makefile is supported as generator
cmake -S . -B build -G "MSYS Makefiles"

# Build and install
cd build
make -j2
make install

# Or directly run `make install` instead. It will build first
make -j2 install
```

## CMake options

You can specify some options when invoking CMake. They will control Zyn-Fusion or build system's behavior.

### `-DCROSS_WINDOWS=1`

Enable cross-build for Windows if your host is Linux.

### `-DPARALLEL_BUILD_DEPS=1`

Enable parallel build on dependencies.

Trade-off is that you cannot use `-jn` when invoking `make` in build path, as it may slow down your machine.

### `-DPARALLEL_BUILD_ZYNADDSUBFX=1`

Enable parallel build on ZynAddSubFX.

Trade-off is that you may not compile Zest at the same time via `make -jn`, as it may slow down your machine, moreover your terminal output may mess up.

### `-DPARALLEL_BUILD_ZEST=1`

Enable parallel build on Zest (EXPERIMENTAL).

Trade-off is that you may not compile ZynAddSubFX and other dependencies at the same time via `make -jn`, as it may slow down your machine.

### `-DDEMO_MODE=1`

Enable demo build.

Demo build will automatically go mute every 10 minutes.

## Multi-build support

If you are on Linux, it's possible to build both Windows and Linux version within the same source tree. Build system will separate built files and ZynAddSubFX/Zest source trees by target.

Simply specify different build directories when invoking CMake:

```bash
cmake -S . -B build-windows -DCROSS_WINDOWS=1
cmake -S . -B build-linux
```

Then go to those directories and run `make install`.

## Authors

- **Zyn-Fusion maintainer**: @fundamental

- **This build system**: @anclark 

  Based on the original build scripts by @fundamental.

