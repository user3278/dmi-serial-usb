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
rem start from a fresh copy so placeholders are blank every boot
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
