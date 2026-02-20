# SPDX-License-Identifier: BSD-2-Clause
# SPDX-FileCopyrightText: 2025 Stefan Reinauer
#
# TinySetPatch Makefile

ADATE   := $(shell date '+%-d.%-m.%Y')
# FULL_VERSION is 42.xx-yy-dirty or git hash if no tags exist
FULL_VERSION ?= $(shell v=$$(git describe --tags --dirty 2>/dev/null | sed 's/^release_//'); [ -n "$$v" ] && echo "$$v" || git rev-parse --short HEAD)
PROG_VERSION := $(shell echo $(FULL_VERSION) | cut -f1 -d\.)
PROG_REVISION := $(shell echo $(FULL_VERSION) | cut -f2 -d\.|cut -f1 -d\-)

VASM    := vasmm68k_mot

# NDK include path (override with: make NDK_PATH=/your/path)
NDK_PATH ?= $(shell realpath $$(dirname $$(which $(CC)))/../m68k-amigaos/ndk-include)

.PHONY: all clean

all: disk

clean:
	@echo "  CLEAN"
	@rm -f TinySetPatch*.adf TinySetPatch
	@rm -r MMULib

# Disk creation
DISK = TinySetPatch-$(FULL_VERSION).adf

# Downloads directory and files
DOWNLOAD_DIR = downloads
MMULIB_LHA = $(DOWNLOAD_DIR)/MMULib.lha

# MD5 checksums for verification
MMULIB_MD5 = 5d07a2dc0f495a9c6790fa7d1df43f1d

.PHONY: disk download-libs

# Create downloads directory
$(DOWNLOAD_DIR):
	mkdir -p $(DOWNLOAD_DIR)

# Portable MD5 verification (works on Linux and macOS)
# Usage: $(call verify_md5,file,expected_md5)
# Returns 0 (success) if match, 1 (failure) if mismatch
define md5_cmd
md5sum "$(1)" 2>/dev/null | cut -d' ' -f1 || md5 -q "$(1)" 2>/dev/null
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
		curl -sL http://aminet.net/util/libs/MMULib.lha -o $@; \
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
		MMULib/Libs/680x0.library MMULib/Libs/68020.library \
		MMULib/Libs/68030.library MMULib/Libs/68040.library \
		MMULib/Libs/68060.library

TinySetPatch: TinySetPatch.S
	@echo "  VASM $@"
	@$(VASM) -quiet -Fhunkexe -o $@ -nosym $< -I $(NDK_PATH)

disk: $(TARGET) download-libs TinySetPatch
	@echo "  DISK"
	@xdftool $(DISK) format "TinySetPatch"
	@xdftool $(DISK) makedir Libs
	@for lib in mmu 680x0 68020 68030 68040 68060; do \
		xdftool $(DISK) write MMULib/Libs/$$lib.library Libs/$$lib.library; \
	done
	@xdftool $(DISK) makedir S
	@xdftool $(DISK) write Startup-Sequence S/Startup-Sequence
	@xdftool $(DISK) makedir C
	@xdftool $(DISK) write TinySetPatch C/TinySetPatch
	@xdftool $(DISK) boot install
	@xdftool $(DISK) info
	@ln -sf $(DISK) TinySetPatch.adf
