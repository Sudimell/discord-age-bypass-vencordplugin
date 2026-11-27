@echo off
setlocal enabledelayedexpansion
title AgeVerificationBypass - installer
color 0B
cd /d "%~dp0"

echo.
echo  ==============================================================
echo      AgeVerificationBypass - installer
echo  ==============================================================
echo.
echo  needs a vencord source checkout with pnpm install done
echo.

if not exist "%~dp0install.ps1" goto :bad_package
if not exist "%~dp0..\plugin\ageVerificationBypass\index.ts" goto :bad_package

set "VCD_SRC=C:\Vencord"
set /p VCD_SRC=vencord source path [C:\Vencord]: 
if "%VCD_SRC%"=="" set "VCD_SRC=C:\Vencord"
if not exist "%VCD_SRC%\pnpm-lock.yaml" goto :no_source
if not exist "%VCD_SRC%\src\userplugins" goto :no_source

set "VCD=%APPDATA%\Vencord"
if not exist "%VCD%\dist\patcher.js" goto :no_vencord

set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1""

set "HAS_DISCORD=0"
for %%F in (Discord DiscordCanary DiscordPTB) do (
    if exist "%LOCALAPPDATA%\%%F\Update.exe" (
        %PS% -VencordPath "%VCD_SRC%" -DryRun >nul 2>&1
        set "HAS_DISCORD=1"
    )
)
if "%HAS_DISCORD%"=="0" goto :no_target

set "WAS_STABLE=0"
set "WAS_CANARY=0"
set "WAS_PTB=0"
tasklist /FI "IMAGENAME eq Discord.exe" /NH 2>nul | find /I "Discord.exe" >nul
if not errorlevel 1 set "WAS_STABLE=1"
tasklist /FI "IMAGENAME eq DiscordCanary.exe" /NH 2>nul | find /I "DiscordCanary.exe" >nul
if not errorlevel 1 set "WAS_CANARY=1"
tasklist /FI "IMAGENAME eq DiscordPTB.exe" /NH 2>nul | find /I "DiscordPTB.exe" >nul
if not errorlevel 1 set "WAS_PTB=1"

echo  [1/3] closing clients...
call :stopFlavor Discord
call :stopFlavor DiscordCanary
call :stopFlavor DiscordPTB
taskkill /F /IM DiscordSystemHelper.exe >nul 2>&1
ping -n 3 127.0.0.1 >nul

tasklist /FI "IMAGENAME eq Discord.exe" /NH 2>nul | find /I "Discord.exe" >nul
if not errorlevel 1 goto :still_running

echo  [2/3] building and copying...
%PS% -VencordPath "%VCD_SRC%"
if errorlevel 1 goto :build_failed

echo  [3/3] reopening...
call :startFlavor Discord Discord
call :startFlavor DiscordCanary DiscordCanary
call :startFlavor DiscordPTB DiscordPTB
if not defined STARTED call :startFallback
ping -n 4 127.0.0.1 >nul

echo.
echo  done. enable AgeVerificationBypass in settings - vencord - plugins
echo.
pause
exit /b 0

:: ── helpers ───────────────────────────────────────────────────

:stopFlavor
tasklist /FI "IMAGENAME eq %~1.exe" /NH 2>nul | find /I "%~1.exe" >nul
if errorlevel 1 goto :eof
set "WAS_%~1=1"
taskkill /F /IM %~1.exe >nul 2>&1
goto :eof

:startFlavor
if not defined WAS_%~1 goto :eof
start "" "%LOCALAPPDATA%\%~2\Update.exe" --processStart %~2.exe
set "STARTED=1"
goto :eof

:startFallback
set "ONLY="
set "COUNT="
for %%F in (Discord DiscordCanary DiscordPTB) do (
    if exist "%LOCALAPPDATA%\%%F\Update.exe" (
        set /a COUNT+=1
        set "ONLY=%%F"
    )
)
if "%COUNT%"=="1" (
    start "" "%LOCALAPPDATA%\%ONLY%\Update.exe" --processStart %ONLY%.exe
    goto :eof
)
echo  nothing was running, open your client yourself
goto :eof

:: ── failures ──────────────────────────────────────────────────

:bad_package
color 0C
echo  ERROR: broken package. the plugin folder must sit next to installer\
pause
exit /b 1

:no_source
color 0C
echo  ERROR: no vencord source at that path
echo    git clone https://github.com/Vendicated/Vencord.git C:\Vencord
echo    cd C:\Vencord
echo    pnpm install
pause
exit /b 1

:no_vencord
color 0C
echo  ERROR: vencord is not installed for discord clients
echo  https://vencord.dev/download
pause
exit /b 1

:no_target
color 0C
echo  ERROR: no discord client found
pause
exit /b 1

:still_running
color 0C
echo  ERROR: a client did not close. close it by hand and retry
call :startFallback
pause
exit /b 1

:build_failed
color 0C
echo.
echo  ERROR: build failed. restoring previous vencord files...
if exist "%VCD%\dist.avb-backup\" (
    rmdir /S /Q "%VCD%\dist" >nul 2>&1
    robocopy "%VCD%\dist.avb-backup" "%VCD%\dist" /E /NFL /NDL /NJH /NJS /NP >nul
)
call :startFallback
pause
exit /b 1
