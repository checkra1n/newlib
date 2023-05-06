ARCH                        := aarch64-none-darwin
SRC                         := src
BUILD                       := build
# XXX: This makes PREFIX an absolute path, which breaks if there's spaces in any path component and
#      kills the ability to move the repo around without a "make distclean", but for now, newlib requires this.
PREFIX                      := $(shell pwd)

ifndef HOST_OS
    ifeq ($(OS),Windows_NT)
        HOST_OS             := Windows
    else
        HOST_OS             := $(shell uname -s)
    endif
endif

# Toolchain
ifdef LLVM_AR
    EMBEDDED_AR             ?= $(LLVM_AR)
endif
ifdef LLVM_RANLIB
    EMBEDDED_RANLIB         ?= $(LLVM_RANLIB)
endif

ifdef LLVM_CONFIG
    EMBEDDED_LLVM_CONFIG    ?= $(LLVM_CONFIG)
endif

# ifdef+ifndef is ugly, but we really don't wanna use ?= when shell expansion is involved
ifdef EMBEDDED_LLVM_CONFIG
ifndef EMBEDDED_LLVM_BINDIR
    EMBEDDED_LLVM_BINDIR    := $(shell $(EMBEDDED_LLVM_CONFIG) --bindir)
endif
endif

ifdef LLVM_BINDIR
    EMBEDDED_LLVM_BINDIR    ?= $(LLVM_BINDIR)
endif

ifdef EMBEDDED_LLVM_BINDIR
    EMBEDDED_CC             ?= $(EMBEDDED_LLVM_BINDIR)/clang
    EMBEDDED_LD             ?= $(EMBEDDED_LLVM_BINDIR)/ld64.lld
    EMBEDDED_AR             ?= $(EMBEDDED_LLVM_BINDIR)/llvm-ar
    EMBEDDED_RANLIB         ?= $(EMBEDDED_LLVM_BINDIR)/llvm-ranlib
endif

CLANG                       ?= clang

ifeq ($(HOST_OS),Darwin)
    EMBEDDED_CC             ?= xcrun -sdk iphoneos clang
    EMBEDDED_AR             ?= ar
    EMBEDDED_RANLIB         ?= ranlib
else
ifeq ($(HOST_OS),Linux)
    EMBEDDED_CC             ?= $(CLANG)
    EMBEDDED_LD             ?= lld
    EMBEDDED_AR             ?= llvm-ar
    EMBEDDED_RANLIB         ?= llvm-ranlib
endif
endif

ifdef EMBEDDED_LD
    EMBEDDED_LDFLAGS        ?= -fuse-ld='$(EMBEDDED_LD)'
endif

# Safeguard against GNU ar/ranlib
ifneq ($(shell $(EMBEDDED_AR) V 2>&1 | grep -F 'GNU ar' || true),)
    $(error GNU ar detected, need LLVM ar)
endif
ifneq ($(shell $(EMBEDDED_RANLIB) -V 2>&1 | grep -F 'GNU ranlib' || true),)
    $(error GNU ranlib detected, need LLVM ranlib)
endif

EMBEDDED_CC_FLAGS           ?= --target=arm64-apple-ios12.0 -std=gnu17 -Wall -Os -flto -moutline -ffreestanding -nostdlibinc -fno-blocks -U__nonnull -D_LDBL_EQ_DBL -DABORT_PROVIDED -DGETREENT_PROVIDED -DREENTRANT_SYSCALLS_PROVIDED -D__DYNAMIC_REENT__ $(EMBEDDED_CFLAGS) $(NEWLIB_CFLAGS)
EMBEDDED_LD_FLAGS           ?= $(EMBEDDED_LDFLAGS) $(NEWLIB_LDFLAGS)

.PHONY: all always clean distclean

all: $(ARCH)/fixup/libc.a

# We need to replace the implementation of __stack_chk_fail and __chk_fail
$(ARCH)/fixup/libc.a: $(ARCH)/lib/libc.a | $(ARCH)/fixup
	cp $< $@
	$(EMBEDDED_AR) -d $@ lib_a-stack_protector.o lib_a-chk_fail.o

# Actual targets
$(ARCH)/lib/libc.a: $(BUILD)/libc.a
	$(MAKE) -C $(BUILD) install

$(BUILD)/libc.a: $(BUILD)/Makefile always
	$(MAKE) -C $(BUILD) all

# Dependency
$(BUILD)/Makefile: Makefile $(SRC)/newlib/configure $(SRC)/newlib/Makefile.in | $(BUILD)
	cd $(BUILD) && \
	../$(SRC)/newlib/configure \
		--prefix='$(PREFIX)' \
		--host=$(ARCH) \
		--enable-target-optspace \
		--enable-newlib-io-c99-formats \
		--enable-newlib-io-long-long \
		--enable-newlib-global-stdio-streams \
		--disable-newlib-io-float \
		--disable-newlib-io-long-double \
		--disable-newlib-supplied-syscalls \
		--disable-newlib-mb \
		--disable-newlib-wide-orient \
		--disable-newlib-register-fini \
		--disable-multilib \
		--disable-shared \
		--enable-static \
		CC='$(EMBEDDED_CC)' \
		CFLAGS='$(EMBEDDED_CC_FLAGS)' \
		LDFLAGS='$(EMBEDDED_LD_FLAGS)' \
		AR='$(EMBEDDED_AR)' \
		RANLIB='$(EMBEDDED_RANLIB)' \
	;
	$(MAKE) -C $(BUILD) clean

$(BUILD) $(ARCH)/fixup:
	mkdir -p $@

clean:
	rm -rf $(ARCH)
	@test -f $(BUILD)/Makefile && $(MAKE) -C $(BUILD) clean

distclean:
	rm -rf $(BUILD) $(ARCH)
