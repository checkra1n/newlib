ifndef $(HOST_OS)
	ifeq ($(OS),Windows_NT)
		HOST_OS := Windows
	else
		HOST_OS := $(shell uname -s)
	endif
endif

ifeq ($(HOST_OS),Darwin)
	EMBEDDED_CC         ?= xcrun -sdk iphoneos clang
	EMBEDDED_AR         ?= ar
	EMBEDDED_RANLIB     ?= ranlib
else
ifeq ($(HOST_OS),Linux)
	EMBEDDED_CC         ?= clang
	EMBEDDED_LDFLAGS    ?= -fuse-ld=/usr/bin/ld64
	EMBEDDED_AR         ?= llvm-ar
	EMBEDDED_RANLIB     ?= llvm-ranlib
endif
endif

EMBEDDED_CC_FLAGS       ?= --target=arm64-apple-ios12.0 -Wall -O3 -ffreestanding -nostdlib -nostdlibinc -fno-builtin -fno-blocks -U__nonnull -D_LDBL_EQ_DBL $(EMBEDDED_CFLAGS)
EMBEDDED_LD_FLAGS       ?= $(EMBEDDED_LDFLAGS)

ARCH                    := aarch64-none-darwin
ROOT                    := $(shell pwd)
SRC                     := $(ROOT)/src
BUILD                   := $(ROOT)/build
PREFIX                  := $(ROOT)

.PHONY: all always clean distclean

all: $(patsubst %, $(ARCH)/lib/%, libc.a libg.a libm.a)

# Actual targets
$(ARCH)/lib/libc.a: $(patsubst %, $(BUILD)/%, libc.a libg.a libm.a)
	$(MAKE) $(AM_MAKEFLAGS) -C $(BUILD) install

$(BUILD)/libc.a: $(BUILD)/Makefile always
	$(MAKE) $(AM_MAKEFLAGS) -C $(BUILD) all

# Multiple output hell
$(ARCH)/lib/libg.a: $(ARCH)/lib/libc.a
	@test -f $@ || $(MAKE) $(AM_MAKEFLAGS) -C $(BUILD) install

$(ARCH)/lib/libm.a: $(ARCH)/lib/libg.a
	@test -f $@ || $(MAKE) $(AM_MAKEFLAGS) -C $(BUILD) install

$(BUILD)/libg.a: $(BUILD)/libc.a
	@test -f $@ || $(MAKE) $(AM_MAKEFLAGS) -C $(BUILD) all

$(BUILD)/libm.a: $(BUILD)/libg.a
	@test -f $@ || $(MAKE) $(AM_MAKEFLAGS) -C $(BUILD) all

# Dependency
$(BUILD)/Makefile: $(ROOT)/Makefile $(SRC)/newlib/configure $(SRC)/newlib/Makefile.in | $(BUILD)
	cd $(BUILD); \
	$(SRC)/newlib/configure \
		--prefix='$(PREFIX)' \
		--host=$(ARCH) \
		--enable-newlib-io-c99-formats \
		--enable-newlib-io-long-long \
		--disable-newlib-io-float \
		--disable-newlib-supplied-syscalls \
		--disable-multilib \
		--disable-shared \
		--enable-static \
		CC='$(EMBEDDED_CC)' \
		CFLAGS='$(EMBEDDED_CC_FLAGS)' \
		LDFLAGS='$(EMBEDDED_LD_FLAGS)' \
		AR='$(EMBEDDED_AR)' \
		RANLIB='$(EMBEDDED_RANLIB)' \
	;

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(ARCH)
	@test -f $(BUILD)/Makefile || $(MAKE) $(AM_MAKEFLAGS) -C $(BUILD) clean

distclean:
	rm -rf $(BUILD) $(ARCH)
