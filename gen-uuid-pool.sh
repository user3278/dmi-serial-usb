#!/usr/bin/env bash
#
# gen-uuid-pool.sh [COUNT]
#
# Pre-generates COUNT sets of random UUIDs (default 50) onto the DMI-edit USB and
# installs a dispatcher startup.nsh. Each time you boot the USB on a machine, the
# UEFI shell runs the LOWEST-numbered unused set, applies it, then DELETES it so
# the next machine gets a different, unique set. No PC/Linux needed between systems.
#
# Each set writes, all to distinct random UUIDs:
#     System serial    (/SS)
#     Baseboard serial (/BS)
#     Chassis serial   (/CS)
#     System UUID      (/SU)
#
# Re-run this script to refill the pool once it's been used up.

set -euo pipefail

COUNT="${1:-50}"
case "$COUNT" in (*[!0-9]*|'') echo "COUNT must be a number" >&2; exit 1;; esac

# --- locate the USB stick (the volume that holds AMIDEEFIx64.EFI) ---------
USB=""
for base in /media/"$USER"/* /run/media/"$USER"/* /media/* /mnt/*; do
    [ -f "$base/EFI/BOOT/AMIDEEFIx64.EFI" ] && { USB="$base"; break; }
done
[ -z "$USB" ] && { echo "ERROR: USB with EFI/BOOT/AMIDEEFIx64.EFI not found under /media or /mnt." >&2; exit 1; }
echo "USB found at: $USB"

SETS_DIR="$USB/EFI/BOOT/sets"
MANIFEST="$USB/uuid-manifest.csv"

# helper: write stdin to a file with CRLF line endings (safest for UEFI shell)
crlf() { sed 's/$/\r/' > "$1"; }

# --- (re)create the pool ---------------------------------------------------
rm -rf "$SETS_DIR"
mkdir -p "$SETS_DIR"
echo "set,system_serial,baseboard_serial,chassis_serial,system_uuid" > "$MANIFEST"

for i in $(seq 1 "$COUNT"); do
    SS="$(uuidgen)"; BS="$(uuidgen)"; CS="$(uuidgen)"
    crlf "$SETS_DIR/$i.nsh" <<EOF
echo   Set $i
echo   System serial   : $SS
AMIDEEFIx64.EFI /SS "$SS"
echo   Baseboard serial: $BS
AMIDEEFIx64.EFI /BS "$BS"
echo   Chassis serial  : $CS
AMIDEEFIx64.EFI /CS "$CS"
echo   System UUID     : AUTO (firmware-generated)
AMIDEEFIx64.EFI /SU AUTO
EOF
    echo "$i,$SS,$BS,$CS,AUTO" >> "$MANIFEST"
done

# --- install the dispatcher startup.nsh -----------------------------------
# Unquoted heredoc so $COUNT is baked into the loop range. Backslashes in EFI
# paths are preserved by bash here (none are followed by a special char).
crlf "$USB/EFI/BOOT/startup.nsh" <<EOF
@echo -off
echo ============================================
echo  DMI serial programmer  (unique per system)
echo ============================================
rem find whichever fsN: is this USB, then move into the tool directory
for %i in 0 1 2 3 4 5 6 7 8 9
  if exist fs%i:\EFI\BOOT\AMIDEEFIx64.EFI then
    fs%i:
  endif
endfor
cd \EFI\BOOT
rem clear any leftover flag from a prior interrupted boot
if exist applied.flg then
  del applied.flg
endif
rem run ONLY the lowest-numbered unused set; the flag stops after exactly one
for %n run (1 $COUNT)
  if exist sets\%n.nsh then
    if not exist applied.flg then
      echo Applying UUID set %n ...
      sets\%n.nsh
      del sets\%n.nsh
      echo done > applied.flg
    endif
  endif
endfor
if exist applied.flg then
  del applied.flg
  echo.
  echo  Set applied and consumed. Remove USB and reboot to verify.
else
  echo.
  echo  !! No unused UUID sets left on this stick.
  echo  !! Re-run gen-uuid-pool.sh on your PC to refill.
endif
EOF

# a root-level copy too, in case a shell searches the volume root first
cp "$USB/EFI/BOOT/startup.nsh" "$USB/startup.nsh"
cp "$MANIFEST" "/home/$USER/Downloads/uuid-manifest.csv" 2>/dev/null || true
sync

# --- report ----------------------------------------------------------------
echo
echo "Installed $COUNT unique UUID sets:"
echo "  sets dir : $SETS_DIR  ($COUNT files: 1.nsh .. $COUNT.nsh)"
echo "  dispatch : $USB/EFI/BOOT/startup.nsh  (+ root copy)"
echo "  manifest : $MANIFEST  (and a copy in ~/Downloads)"
echo
echo "Each USB boot consumes ONE set (lowest number first) and deletes it,"
echo "so every system you touch gets a different, unique set."
echo "First three sets that will be used, in order:"
head -4 "$MANIFEST" | column -s, -t
