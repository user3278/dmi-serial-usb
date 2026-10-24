# dmi-serial-usb

Set the DMI/SMBIOS **serial numbers** (system, baseboard, chassis) and **system
UUID** of a PC by booting a USB stick into the UEFI shell and driving AMI's
`AMIDEEFIx64.EFI` DMI editor. Three helper scripts build the USB in three
different styles, from fully manual entry to pre-generated random pools.

> Intended for your own hardware / lab provisioning. Changing DMI identifiers can
> affect OEM warranty lookups, license activation, and asset tracking — know why
> you're doing it.

## What's on the USB

A FAT-formatted stick with a UEFI shell set up to auto-run `startup.nsh`.
The full bootable payload is committed under `EFI/BOOT/`:

```
EFI/BOOT/
  BOOTX64.efi        <- UEFI shell (x64)
  BootIa32.efi       <- UEFI shell (ia32)
  AMIDEEFIx64.EFI    <- AMI DMI editor
  startup.nsh        <- auto-runs on boot (manual-entry build)
  template.nsh       <- the fields you fill in
```

To build a stick: copy the `EFI/` tree to the root of a FAT32 USB. To change
which flow runs, regenerate `startup.nsh`/`template.nsh` with one of the scripts
below.

> **Binaries:** `BOOTX64.efi`, `BootIa32.efi`, and `AMIDEEFIx64.EFI` are AMI /
> third-party tools included here for convenience in this **private** repo. They
> are proprietary — do not make this repo public or redistribute them.

## AMIDEEFI switches used

| Switch | Field | Notes |
|--------|-------|-------|
| `/SS`  | System serial (SMBIOS Type 1)    | free string |
| `/BS`  | Baseboard serial (Type 2)        | free string |
| `/CS`  | Chassis serial (Type 3)          | free string |
| `/SU`  | System UUID (Type 1)             | use `AUTO` — see caveats |

A switch with **no value is a read** (it just displays the current value);
a value after the switch is a **write**.

## The three scripts

Each is a Linux helper you run with the USB mounted; it writes the right
`.nsh` files onto the stick (CRLF line endings, as the UEFI shell expects).

### `install-serial-entry.sh` — manual entry (recommended)
Auto-runs on boot and opens the UEFI shell's full-screen editor on a template
with one labeled line per field. You type **8–20 alphanumeric, non-repeating**
characters over each placeholder, press **F2** to save and **F3** to exit, and
it applies them. System UUID is set to `AUTO`.

### `gen-uuid-pool.sh [COUNT]` — unique random set per boot
Pre-generates `COUNT` sets (default 50) of random UUID serials into
`EFI/BOOT/sets/` plus a dispatcher. Each boot consumes the lowest-numbered
unused set and deletes it, so every machine gets a different, unique set with no
PC in between. Refill by re-running. A `uuid-manifest.csv` records every set.

### `gen-dmi-serials.sh` — one random set
Generates a single set of random UUID serials and bakes them into `startup.nsh`.
Simplest; re-run for fresh values.

## Usage

```bash
# plug in the USB (must already contain EFI/BOOT/AMIDEEFIx64.EFI), then:
./install-serial-entry.sh          # manual-entry build
# or
./gen-uuid-pool.sh 100             # 100 unique random sets
# or
./gen-dmi-serials.sh               # one random set

# safely eject, boot the stick on the target, let it run, then verify:
sudo dmidecode -t 1 -t 2 -t 3
```

## Caveats (learned the hard way)

- **System UUID must be `AUTO`.** On at least one board (ASRock B850M Pro RS),
  `/SU` with a full 36-char UUID is rejected; `AUTO` lets the firmware generate
  a valid random UUID instead. `dmidecode` may show its first fields
  byte-swapped — that's the SMBIOS storage convention, not an error.
- **No input validation is possible.** The UEFI shell has no `read` command and
  AMIDEEFI has no interactive write mode, so length and the "non-repeating" rule
  in the manual-entry flow are advisory only — whatever you type is applied.
- **Auto-run depends on the shell honoring `startup.nsh`.** If a machine drops to
  a `Shell>` prompt instead, the dispatcher is in `EFI/BOOT/` (and some builds
  also look at the volume root).
- **`.nsh` files need CRLF line endings.** The scripts handle this; hand-edits
  should preserve it.
- **Verify after reboot.** The values live in SMBIOS; confirm on the target with
  `dmidecode` rather than assuming the write stuck.

## Requirements

- Linux with `bash`, `uuidgen`, and a mounted FAT USB
- `dmidecode` to verify
- A UEFI shell (`BOOTX64.efi`) and `AMIDEEFIx64.EFI` placed in `EFI/BOOT/`
