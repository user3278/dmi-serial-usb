#!/usr/bin/env bash
#
# gen-dmi-serials.sh
# Generates random UUIDs and writes a startup.nsh onto the DMI-edit USB stick.
# On the next boot of that USB, the UEFI shell auto-runs startup.nsh, which calls
# AMIDEEFIx64.EFI to set:
#     System serial    (/SS)  -> random UUID
#     Baseboard serial (/BS)  -> random UUID
#     Chassis serial   (/CS)  -> random UUID
#     System UUID      (/SU)  -> random UUID (generated here with uuidgen)
#
# Re-run this script any time you want fresh random serials, then boot the USB.

set -euo pipefail

# --- locate the USB stick (the volume that holds AMIDEEFIx64.EFI) ---------
USB=""
for base in /media/"$USER"/* /run/media/"$USER"/* /media/* /mnt/*; do
    [ -f "$base/EFI/BOOT/AMIDEEFIx64.EFI" ] && { USB="$base"; break; }
done

if [ -z "$USB" ]; then
    echo "ERROR: could not find the USB (no EFI/BOOT/AMIDEEFIx64.EFI under /media or /mnt)." >&2
    echo "       Plug it in / mount it, then re-run. Or set USB=/path manually." >&2
    exit 1
fi
echo "USB found at: $USB"

# --- generate the random values -------------------------------------------
SS_UUID="$(uuidgen)"
BS_UUID="$(uuidgen)"
CS_UUID="$(uuidgen)"
SU_UUID="$(uuidgen)"

# --- build startup.nsh -----------------------------------------------------
# The loop finds whichever fsN: maps to this USB, then cd's to the tool dir.
read -r -d '' NSH <<EOF || true
@echo -off
echo Setting random DMI serial numbers...
for %i in 0 1 2 3 4 5 6 7 8 9
  if exist fs%i:\\EFI\\BOOT\\AMIDEEFIx64.EFI then
    fs%i:
  endif
endfor
cd \\EFI\\BOOT
echo   System serial   : $SS_UUID
AMIDEEFIx64.EFI /SS "$SS_UUID"
echo   Baseboard serial: $BS_UUID
AMIDEEFIx64.EFI /BS "$BS_UUID"
echo   Chassis serial  : $CS_UUID
AMIDEEFIx64.EFI /CS "$CS_UUID"
echo   System UUID     : $SU_UUID
AMIDEEFIx64.EFI /SU "$SU_UUID"
echo.
echo Done. Remove the USB and reboot into your OS to verify.
EOF

# Write to both common startup.nsh locations so any UEFI shell finds it.
printf '%s\n' "$NSH" > "$USB/startup.nsh"
printf '%s\n' "$NSH" > "$USB/EFI/BOOT/startup.nsh"

# --- report ----------------------------------------------------------------
echo
echo "Wrote startup.nsh to:"
echo "  $USB/startup.nsh"
echo "  $USB/EFI/BOOT/startup.nsh"
echo
echo "Values that will be written on next USB boot:"
echo "  System serial    (/SS): $SS_UUID"
echo "  Baseboard serial (/BS): $BS_UUID"
echo "  Chassis serial   (/CS): $CS_UUID"
echo "  System UUID      (/SU): $SU_UUID"
echo
echo "Next: safely eject, boot the USB. It auto-runs and applies the values."
sync
