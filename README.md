# TinySetPatch

A minimal SetPatch replacement for Amiga that fits on a bootable floppy disk. Loads CPU-specific 68020/68030/68040/68060.library files and applies essential system patches.

## Features

- **CPU Detection**: Automatically detects 68000 through 68060 processors
- **CPU Library Loading**: Loads the appropriate CPU library from MMULib
- **AttnFlags**: Sets proper CPU flags in ExecBase for software compatibility
- **Exception Vectors**: Installs handlers for 68060 F-line, unimplemented FP, and unimplemented integer instructions
- **AGA Support**: Enable AGA display modes when possible and 64-bit fetch mode
- **Data Cache**: Enables CPU caches for improved performance
- **SetPatch Semaphore**: Creates the "SetPatch" semaphore that 68060.library requires

## Usage

```
TinySetPatch [QUIET]
```

**Options:**
- `QUIET` - Suppress all output (useful for startup-sequence)

## Building

Requires:
- `vasmm68k_mot` (VASM assembler)
- `xdftool` (from amitools)
- `lha` (for extracting MMULib)
- `curl` (for downloading MMULib)
- Amiga NDK includes

```bash
make            # Build bootable ADF
make clean      # Remove build artifacts
```

The Makefile automatically downloads MMULib from Aminet and extracts the required libraries.

## Bootable Disk Contents

The generated ADF contains:

```
C/TinySetPatch      - The main executable
Libs/mmu.library    - MMU library
Libs/68020.library  - 68020 support
Libs/68030.library  - 68030 support
Libs/68040.library  - 68040 support
Libs/68060.library  - 68060 support
S/Startup-Sequence  - Boot script
```

## Example Startup-Sequence

```
TinySetPatch QUIET
```

## Compatibility

- **Tested**: Kickstart 3.2.3
- **Should work**: Kickstart 1.3 and later

## How It Works

TinySetPatch implements a patch table system similar to the original SetPatch:

1. **Patch 0 - 680x0 Support**: Detects CPU, sets AttnFlags, fixes vector 7 alignment, installs 68060 exception vectors, and loads the appropriate CPU-specific library
2. **Patch 1 - AGA Graphics**: Opens graphics.library V39 and calls `SetChipRev(SETCHIPREV_BEST)` so the OS updates its display database; falls back to LISAID/FMODE only on older systems
3. **Patch 2 - Data Cache**: Enables instruction and data caches with CPU-appropriate settings

Before applying patches, TinySetPatch creates the standard SetPatch semaphore
required by 68060.library. It advertises compatibility version 45.15, which is
separate from TinySetPatch's executable version. The same allocation contains
an identification record at byte offset 80 (0x50): eight ASCII bytes `TinySetP`,
followed by two `UWORD` fields holding the executable version and revision
(currently 0 and 1, at offsets 88 and 90). The allocation is 92 bytes long and
remains allocated after TinySetPatch exits.

Ordinary SetPatch and older TinySetPatch builds do not provide this record.
Readers must guard the probe before reading even the signature. xSysInfo reads
the record only when it lies entirely within the same 256-byte block as the
last byte of the known-valid `SignalSemaphore` header. This avoids crossing
an MMU page boundary on the 68851/68030 as well as the 68040/68060. When the
guard fails, it displays just the SetPatch compatibility version; identification
can therefore be skipped even when the next block is readable.

## Credits

CPU-specific 680x0 libraries are from [MMULib](http://aminet.net/util/libs/MMULib.lha) by Thomas Richter.

## Contributing

Contributions welcome! Please submit pull requests or open issues on GitHub.

## License

This project is licensed under the BSD 2-Clause License. See [LICENSE](LICENSE) for details.

Note: The MMULib libraries included in the generated disk have their own license terms.
