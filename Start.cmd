@echo off
rem Win11Zen - double-click to run the guided setup.
rem Runs with normal rights. Nothing is changed until you type Y.
title Win11Zen
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Win11Zen.ps1" -Mode Guided
echo.
pause
