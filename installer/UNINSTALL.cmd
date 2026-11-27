@echo off
setlocal enabledelayedexpansion
title AgeVerificationBypass - uninstall
color 0E
cd /d "%~dp0"

echo.
echo  restores the vencord files from before the installer
echo.

set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0helper.ps1""
set "VCD=%APPDATA%\Vencord"
set "BAK=%VCD%\dist.avb-backup"

set "WAS_STABLE=0"
set "WAS_CANARY=0"
set "WAS_PTB=0"
tasklist /FI "IMAGENAME eq Discord.exe" /NH 2>nul | find /I "Discord.exe" >nul
if not errorlevel 1 set "WAS_STABLE=1"
tasklist /FI "IMAGENAME eq DiscordCanary.exe" /NH 2>nul | find /I "DiscordCanary.exe" >nul
if not errorlevel 1 set "WAS_CANARY=1"
tasklist /FI "IMAGENAME eq DiscordPTB.exe" /NH 2>nul | find /I "DiscordPTB.exe" >nul
if not errorlevel 1 set "WAS_PTB=1"

taskkill /F /IM Discord.exe >nul 2>&1
taskkill /F /IM DiscordCanary.exe >nul 2>&1
taskkill /F /IM DiscordPTB.exe >nul 2>&1
taskkill /F /IM DiscordSystemHelper.exe >nul 2>&1
ping -n 3 127.0.0.1 >nul

if exist "%BAK%\" (
    rmdir /S /Q "%VCD%\dist" >nul 2>&1
    robocopy "%BAK%" "%VCD%\dist" /E /NFL /NDL /NJH /NJS /NP >nul
    rmdir /S /Q "%BAK%" >nul 2>&1
    echo  vencord files restored
) else (
    echo  no backup found, run the vencord installer - repair
)

%PS% disable "%VCD%\settings\settings.json" >nul 2>&1

if "%WAS_STABLE%"=="1" start "" "%LOCALAPPDATA%\Discord\Update.exe" --processStart Discord.exe
if "%WAS_CANARY%"=="1" start "" "%LOCALAPPDATA%\DiscordCanary\Update.exe" --processStart DiscordCanary.exe
if "%WAS_PTB%"=="1" start "" "%LOCALAPPDATA%\DiscordPTB\Update.exe" --processStart DiscordPTB.exe

echo.
echo  done
pause
