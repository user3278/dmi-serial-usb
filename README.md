# dmi-serial-usb

Set the DMI/SMBIOS **serial numbers** (system, baseboard, chassis) and **system
UUID** of a PC by booting a USB stick into the UEFI shell and driving AMI's
`AMIDEEFIx64.EFI` DMI editor. Three helper scripts build the USB in three
different styles, from fully manual entry to pre-generated random pools.

> Intended for your own hardware / lab provisioning. Changing DMI identifiers can
> affect OEM warranty lookups, license activation, and asset tracking — know why
> you're doing it.

## What's on the USB

A FAT-formatted stick with a UEFI shell. It does **not** auto-run — you boot to
the `Shell>` prompt and launch the tool yourself. The full bootable payload is
committed under `EFI/BOOT/`:

```
EFI/BOOT/
  BOOTX64.efi        <- UEFI shell (x64)
  BootIa32.efi       <- UEFI shell (ia32)
  AMIDEEFIx64.EFI    <- AMI DMI editor
  setserials.nsh     <- guided editor; run BY NAME (not auto-run)
  template.nsh       <- the fields you fill in
```

To build a stick: copy the `EFI/` tree to the root of a FAT32 USB. There is no
`startup.nsh`, so the shell drops to a prompt; run `setserials.nsh` for the
guided editor, or drive AMIDEEFI by hand (below).

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

## Manual usage — check & set by hand

If you'd rather drive the tool yourself instead of using the auto-run scripts,
boot the USB and work at the UEFI shell prompt.

**1. Get a shell prompt.** There is no `startup.nsh`, so the stick boots
straight to a `Shell>` prompt — nothing runs on its own.

**2. Find the USB and go to the tool.**
```
map -r                     # list filesystems (note which fsN: is the USB)
fs0:                       # switch to it (could be fs1:, fs2:, ... — try map output)
cd EFI\BOOT                # where AMIDEEFIx64.EFI lives
```

**3. CHECK — read the current values** (no value after a switch = read):
```
AMIDEEFIx64.EFI /ALL       # dump all DMI fields the tool knows
AMIDEEFIx64.EFI /SS        # system serial   (SMBIOS Type 1)
AMIDEEFIx64.EFI /BS        # baseboard serial (Type 2)
AMIDEEFIx64.EFI /CS        # chassis serial   (Type 3)
AMIDEEFIx64.EFI /SU        # system UUID      (Type 1)
```
You can also use the shell's own `smbios` command to display raw SMBIOS tables.

**4. SET — write new values** (put the value after the switch):
```
AMIDEEFIx64.EFI /SS A1b2C3d4E5f6         # set system serial
AMIDEEFIx64.EFI /BS K9m8N7p6Q5r4         # set baseboard serial
AMIDEEFIx64.EFI /CS Z2y3X4w5V6u7         # set chassis serial
AMIDEEFIx64.EFI /SU AUTO                 # randomize system UUID (see caveats)
```
Quotes are optional when the value has no spaces. Use 8–20 alphanumeric chars
per serial if you want a sane range (not enforced by the tool).

**Guided alternative.** Instead of typing the set commands, run the editor tool:
```
cd EFI\BOOT
setserials.nsh
```
It opens the shell editor on a template with one line per serial; type your
values, **F2** to save, **F3** to exit, and it applies them.

**5. VERIFY.** Re-read with the `/SS /BS /CS /SU` read commands above, or reboot
into your OS and check:
```
sudo dmidecode -t 1 -t 2 -t 3
# or
sudo cat /sys/class/dmi/id/product_serial /sys/class/dmi/id/board_serial \
         /sys/class/dmi/id/chassis_serial /sys/class/dmi/id/product_uuid
```

> **Secure Boot must be OFF.** AMIDEEFI loads a kernel driver to write SMBIOS and
> will fail with *"Unable to generate driver automatically when Secure Boot is
> enabled"* otherwise. Disable Secure Boot in BIOS/UEFI setup first.

## The three scripts

Each is a Linux helper you run with the USB mounted; it writes the right
`.nsh` files onto the stick (CRLF line endings, as the UEFI shell expects).

### `install-serial-entry.sh` — manual entry (recommended)
Installs `setserials.nsh` (run by name — **no auto-run**). At the shell prompt
you launch it; it opens the UEFI shell's full-screen editor on a template with
one labeled line per field. You type **8–20 alphanumeric, non-repeating**
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

> Note: `gen-uuid-pool.sh` and `gen-dmi-serials.sh` install an **auto-running**
> `startup.nsh` by design (hands-free). Only `install-serial-entry.sh` is
> no-auto-run (it uses `setserials.nsh`, launched by name). Ask if you want the
> other two converted to no-auto-run too.

## Usage

```bash
# plug in the USB (must already contain EFI/BOOT/AMIDEEFIx64.EFI), then:
./install-serial-entry.sh          # manual-entry build
# or
./gen-uuid-pool.sh 100             # 100 unique random sets
# or
./gen-dmi-serials.sh               # one random set

# safely eject and boot the stick on the target:
#   - manual build: at the Shell> prompt run  cd EFI\BOOT  then  setserials.nsh
#   - pool/single builds: they auto-run on boot
# then verify:
sudo dmidecode -t 1 -t 2 -t 3
```

## Caveats (learned the hard way)

- **Secure Boot must be disabled.** AMIDEEFI needs to load a driver to write
  SMBIOS; with Secure Boot on it errors out ("Unable to generate driver
  automatically when Secure Boot is enabled").
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
