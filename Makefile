# SPDX-License-Identifier: BSD-2-Clause
# SPDX-FileCopyrightText: 2025 Stefan Reinauer
#
# TinySetPatch Makefile

ADATE   := $(shell date '+%-d.%-m.%Y')
# Match xSysInfo's v/release_ tags, retaining commit and dirty suffixes.
# Keep the current version usable until the repository has its first tag.
FULL_VERSION ?= $(shell git describe --tags --dirty 2>/dev/null | sed -E 's/^release_//; s/^v//')
ifeq ($(strip $(FULL_VERSION)),)
FULL_VERSION := 0.2-g$(shell git describe --always --dirty)
endif
FULL_VERSION := $(FULL_VERSION)
PROG_VERSION := $(shell echo $(FULL_VERSION) | cut -f1 -d\.)
PROG_REVISION := $(shell echo $(FULL_VERSION) | cut -f2 -d\.|cut -f1 -d\-)

VASM    := vasmm68k_mot
CC      := m68k-amigaos-gcc

# NDK include path (override with: make NDK_PATH=/your/path)
NDK_PATH ?= $(shell realpath $$(dirname $$(which $(CC)))/../m68k-amigaos/ndk-include)

.PHONY: all clean version.i

all: disk lha

clean:
	@echo "  CLEAN"
	@rm -f TinySetPatch*.adf TinySetPatch
	@rm -f TinySetPatch-*.lha version.i
	@rm -rf MMULib build

# Disk creation
DISK = TinySetPatch-$(FULL_VERSION).adf
LHA_NAME = TinySetPatch-$(FULL_VERSION).lha
LHA_DIR = TinySetPatch-$(FULL_VERSION)

# Downloads directory and files
DOWNLOAD_DIR = downloads
MMULIB_LHA = $(DOWNLOAD_DIR)/MMULib.lha

# MD5 checksums for verification
MMULIB_MD5 = 1e63e42c9d2895d22f896b6d90c26353

.PHONY: disk lha download-libs print-adf-name print-lha-name

print-adf-name:
	@echo $(DISK)

print-lha-name:
	@echo $(LHA_NAME)

# Create downloads directory
$(DOWNLOAD_DIR):
	mkdir -p $(DOWNLOAD_DIR)

# Portable MD5 verification (works on Linux and macOS)
# Usage: $(call verify_md5,file,expected_md5)
# Returns 0 (success) if match, 1 (failure) if mismatch
define md5_cmd
if command -v md5sum >/dev/null 2>&1; then \
	md5sum "$(1)" | cut -d' ' -f1; \
else md5 -q "$(1)"; fi
endef
define verify_md5_cmd
actual=$$( $(call md5_cmd,$(1)) ); \
[ "$$actual" = "$(2)" ]
endef
define md5_fail_msg
actual=$$( $(call md5_cmd,$(1)) ); \
echo "$(1): FAILED (MD5 mismatch)"; \
echo "Expected MD5: $(2)"; \
echo "Got MD5: $$actual"
endef

# Download and verify MMULib.lha
$(MMULIB_LHA): | $(DOWNLOAD_DIR)
	@if [ -f "$@" ] && $(call verify_md5_cmd,$@,$(MMULIB_MD5)); then \
		echo "$@ already downloaded and verified"; \
	else \
		echo "Downloading MMULib.lha..."; \
		curl -fLsS --retry 3 https://aminet.net/util/libs/MMULib.lha -o $@; \
		if $(call verify_md5_cmd,$@,$(MMULIB_MD5)); then \
			echo "$@: OK"; \
		else \
			$(call md5_fail_msg,$@,$(MMULIB_MD5)); rm -f $@; exit 1; \
		fi \
	fi

# Download all libraries
download-libs: $(MMULIB_LHA)
	# Extract MMULib
	@echo "  UNPACK $(MMULIB_LHA)"
	@lha xq $(MMULIB_LHA) MMULib/Libs/mmu.library \
		MMULib/Libs/68020.library \
		MMULib/Libs/68030.library MMULib/Libs/68040.library \
		MMULib/Libs/68060.library

# Kickstart 1.x rejects VASM's default HUNK_RELOC32SHORT hunks.
TinySetPatch: TinySetPatch.S Makefile version.i
	@echo "  VASM $@"
	@$(VASM) -quiet -Fhunkexe -kick1hunks -m68020up -o $@ -nosym $< -I $(NDK_PATH)

# Regenerate metadata and reassemble so tag changes always reach the binary.
version.i:
	@printf '%s\n' \
		'TINY_VERSION EQU $(PROG_VERSION)' \
		'TINY_REVISION EQU $(PROG_REVISION)' \
		'TINY_VERSION_STRING MACRO' \
		'    dc.b "$(FULL_VERSION)"' \
		'    ENDM' \
		'TINY_BUILD_DATE MACRO' \
		'    dc.b "$(ADATE)"' \
		'    ENDM' > $@

lha: TinySetPatch download-libs README.md LICENSE
	@echo "  LHA   $(LHA_NAME)"
	@rm -rf build/$(LHA_DIR)
	@mkdir -p build/$(LHA_DIR)/Libs
	@cp TinySetPatch README.md LICENSE build/$(LHA_DIR)/
	@cp MMULib/Libs/*.library build/$(LHA_DIR)/Libs/
	@rm -f $(LHA_NAME)
	@cd build && lha aqo5 ../$(LHA_NAME) $(LHA_DIR)
	@rm -rf build/$(LHA_DIR)

disk: download-libs TinySetPatch Startup-Sequence
	@echo "  DISK"
	@xdftool $(DISK) format "TinySetPatch"
	@xdftool $(DISK) makedir Libs
	@set -e; for lib in mmu 68020 68030 68040 68060; do \
		xdftool $(DISK) write MMULib/Libs/$$lib.library Libs/$$lib.library; \
	done
	@xdftool $(DISK) makedir S
	@xdftool $(DISK) write Startup-Sequence S/Startup-Sequence
	@xdftool $(DISK) makedir C
	@xdftool $(DISK) write TinySetPatch C/TinySetPatch
	@xdftool $(DISK) boot install
	@xdftool $(DISK) info
	@ln -sf $(DISK) TinySetPatch.adf
