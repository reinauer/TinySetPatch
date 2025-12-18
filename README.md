# TinySetPatch

A minimal SetPatch replacement for Amiga that fits on a bootable floppy disk. Loads CPU-specific 680x0.library files and applies essential system patches.

## Features

- **CPU Detection**: Automatically detects 68000 through 68060 processors
- **680x0.library Loading**: Loads the appropriate CPU library from MMULib
- **AttnFlags**: Sets proper CPU flags in ExecBase for software compatibility
- **Exception Vectors**: Installs handlers for 68060 F-line, unimplemented FP, and unimplemented integer instructions
- **AGA Support**: Enables 64-bit fetch mode on AGA chipsets
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
Libs/680x0.library  - Generic CPU library
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

1. **Patch 0 - 680x0 Support**: Detects CPU, sets AttnFlags, fixes vector 7 alignment, installs 68060 exception vectors, and loads the appropriate 680x0.library
2. **Patch 1 - AGA Graphics**: Detects AGA via LISAID register and enables 64-bit fetch mode
3. **Patch 2 - Data Cache**: Enables instruction and data caches with CPU-appropriate settings

After applying patches, TinySetPatch creates a "SetPatch" semaphore in the system. This semaphore is required by 68060.library and signals to other software that system patches have been applied.

## Credits

680x0 libraries are from [MMULib](http://aminet.net/util/libs/MMULib.lha) by Thomas Richter.

## Contributing

Contributions welcome! Please submit pull requests or open issues on GitHub.

## License

This project is licensed under the BSD 2-Clause License. See [LICENSE](LICENSE) for details.

Note: The MMULib libraries included in the generated disk have their own license terms.
