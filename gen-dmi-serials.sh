#!/usr/bin/env bash
#
# gen-dmi-serials.sh
# Generates random UUIDs and writes setserials.nsh onto the DMI-edit USB stick.
# It does NOT auto-run: boot the USB to the Shell> prompt and launch it by name
# (cd EFI\BOOT then setserials.nsh). It calls AMIDEEFIx64.EFI to set:
#     System serial    (/SS)  -> random UUID
#     Baseboard serial (/BS)  -> random UUID
#     Chassis serial   (/CS)  -> random UUID
#     System UUID      (/SU)  -> AUTO (firmware-generated; a full UUID is
#                                rejected by some boards)
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
BOOT="$USB/EFI/BOOT"

# remove any auto-run file so nothing runs on boot
rm -f "$USB/startup.nsh" "$BOOT/startup.nsh" 2>/dev/null || true

# --- generate the random values -------------------------------------------
SS_UUID="$(uuidgen)"
BS_UUID="$(uuidgen)"
CS_UUID="$(uuidgen)"

# --- build setserials.nsh (run by name, not auto-run) ----------------------
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
echo   System UUID     : AUTO (firmware-generated)
AMIDEEFIx64.EFI /SU AUTO
echo.
echo Done. Remove the USB and reboot into your OS to verify.
EOF

# CRLF line endings for the UEFI shell
printf '%s\n' "$NSH" | sed 's/$/\r/' > "$BOOT/setserials.nsh"

# --- report ----------------------------------------------------------------
echo
echo "Wrote (NO auto-run): $BOOT/setserials.nsh"
echo
echo "Values it will write when you run it:"
echo "  System serial    (/SS): $SS_UUID"
echo "  Baseboard serial (/BS): $BS_UUID"
echo "  Chassis serial   (/CS): $CS_UUID"
echo "  System UUID      (/SU): AUTO (firmware-generated)"
echo
echo "On the target: boot to Shell>, then:  fs0:  /  cd EFI\\BOOT  /  setserials.nsh"
sync
