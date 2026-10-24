#!/usr/bin/env bash
#
# install-serial-entry.sh
#
# Installs a GUIDED serial-entry tool onto the DMI-edit USB. It does NOT auto-run;
# you boot to the UEFI shell prompt and launch it by name:  setserials.nsh
#
# WHY it works this way: the UEFI shell has no command to prompt for and capture
# typed input, and AMIDEEFI has no interactive write mode. The only way to let a
# human type values at the target machine is the shell's built-in full-screen
# editor ("edit"). setserials.nsh opens a fresh template in the editor with one
# labeled line per field; you type over each placeholder, Save (F2), Exit (F3),
# and it applies them.
#
# Fields (replace the underscores with 8 to 20 alphanumeric, NON-REPEATING
# characters A-Z a-z 0-9; the 20 underscores mark the max):
#     System serial    (/SS)
#     Baseboard serial (/BS)
#     Chassis serial   (/CS)
# System UUID (/SU) is set to AUTO (firmware-generated); a full UUID is rejected
# by this board, so AUTO is used. Edit that line if you want.

set -euo pipefail

# --- locate the USB stick --------------------------------------------------
USB=""
for base in /media/"$USER"/* /run/media/"$USER"/* /media/* /mnt/*; do
    [ -f "$base/EFI/BOOT/AMIDEEFIx64.EFI" ] && { USB="$base"; break; }
done
[ -z "$USB" ] && { echo "ERROR: USB with EFI/BOOT/AMIDEEFIx64.EFI not found under /media or /mnt." >&2; exit 1; }
echo "USB found at: $USB"
BOOT="$USB/EFI/BOOT"

crlf() { sed 's/$/\r/' > "$1"; }   # UEFI shell wants CRLF line endings

# remove ANY auto-run file + leftovers so nothing runs on boot
rm -f  "$BOOT/startup.nsh" "$USB/startup.nsh" 2>/dev/null || true
rm -rf "$BOOT/sets" "$USB/uuid-manifest.csv" "$BOOT/applied.flg" "$BOOT/work.nsh" 2>/dev/null || true

# --- the fill-in template (pristine; copied to work.nsh fresh each run) ----
crlf "$BOOT/template.nsh" <<'EOF'
echo Setting SYSTEM serial...
AMIDEEFIx64.EFI /SS ____________________
echo Setting BASEBOARD serial...
AMIDEEFIx64.EFI /BS ____________________
echo Setting CHASSIS serial...
AMIDEEFIx64.EFI /CS ____________________
echo Setting SYSTEM UUID (AUTO = firmware-generated)...
AMIDEEFIx64.EFI /SU AUTO
EOF

# --- the guided tool (run by name: setserials.nsh) -------------------------
crlf "$BOOT/setserials.nsh" <<'EOF'
@echo -off
echo ================================================================
echo   DMI SERIAL ENTRY
echo ================================================================
rem find whichever fsN: is this USB, then move into the tool directory
for %i in 0 1 2 3 4 5 6 7 8 9
  if exist fs%i:\EFI\BOOT\AMIDEEFIx64.EFI then
    fs%i:
  endif
endfor
cd \EFI\BOOT
rem start from a fresh copy so placeholders are blank every run
if exist work.nsh then
  del work.nsh
endif
cp template.nsh work.nsh > NUL
echo.
echo  An editor will open with 3 fields (SS / BS / CS).
echo  For EACH field, replace the underscores with 8 to 20
echo  alphanumeric characters (A-Z a-z 0-9), NON-REPEATING.
echo  (The 20 underscores mark the maximum length.)
echo.
echo  When done:   press  F2  to Save,  then  F3  to Exit.
echo  (System UUID is set to AUTO automatically - leave that line.)
echo.
echo  Press any key to open the editor...
pause
edit work.nsh
echo.
echo  Applying values...
echo ----------------------------------------------------------------
work.nsh
echo ----------------------------------------------------------------
echo  Done. Remove the USB and reboot into your OS to verify.
EOF

# --- keep inspectable copies in Downloads ---------------------------------
cp "$BOOT/setserials.nsh" "/home/$USER/Downloads/setserials.nsh" 2>/dev/null || true
cp "$BOOT/template.nsh"   "/home/$USER/Downloads/template.nsh"   2>/dev/null || true
sync

echo
echo "Installed (NO auto-run):"
echo "  $BOOT/setserials.nsh   (run it yourself at the shell prompt)"
echo "  $BOOT/template.nsh      (the 3 fields you fill in)"
echo "Copies for inspection are in ~/Downloads/setserials.nsh and template.nsh"
echo
echo "On the target: boot the USB to the Shell> prompt, then:"
echo "    fs0:              (or whichever map -r shows)"
echo "    cd EFI\\BOOT"
echo "    setserials.nsh"
