@echo off
rem Win11Zen - double-click to undo every change the script has made.
title Win11Zen - Undo
echo.
echo   This puts back every setting Win11Zen has changed on this PC, using its backups.
echo   It does not uninstall Windhawk. To remove it: Settings, Apps, Installed apps, Windhawk.
echo.
choice /C YN /M "  Undo everything now"
if errorlevel 2 goto cancelled
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Win11Zen.ps1" -Mode Restore -All
goto end
:cancelled
echo.
echo   Cancelled. Nothing was changed.
:end
echo.
pause
