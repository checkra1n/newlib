# Newlib

This repository contains a [Newlib](https://sourceware.org/newlib/) port for bare metal AArch64 with Darwin ABI (`aarch64-none-darwin`).  
This is used as the standard library in [PongoOS](https://github.com/checkra1n/pongoOS).

Some patches had to be applied in order to make it compile with clang and under Darwin ABI.
The current Newlib is based on version 4.1.0.

### Building

If you have `clang` in a standard path and are either on macOS, or have Apple's `ld64` installed to `/usr/bin/ld64`:

    make

If you need to adjust the paths of either clang or the linker:

    EMBEDDED_CC="path/to/clang" EMBEDDED_CFLAGS="<whatever>" EMBEDDED_LDFLAGS="-fuse-ld=path/to/ld64" make

If there's further defaults you need to override, see `EMBEDDED_CC_FLAGS` and `EMBEDDED_LD_FLAGS` in the Makefile.
