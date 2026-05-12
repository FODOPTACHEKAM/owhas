@echo off
setlocal EnableDelayedExpansion

:: ── Self-elevate to Administrator ──────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

echo.
echo ============================================================
echo   OwHAS Attendance Server  --  Setup and Start
echo ============================================================
echo.

:: ── Check Node.js ──────────────────────────────────────────────────────────
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH.
    echo Download from https://nodejs.org/ then re-run this file.
    pause
    exit /b 1
)
for /f "delims=" %%V in ('node -v 2^>nul') do echo Node.js %%V detected.
echo.

:: ── [1/3] Firewall: TCP port 5501, ALL profiles ────────────────────────────
echo [1/3] Configuring Windows Firewall -- TCP port 5501...
netsh advfirewall firewall delete rule name="OwHAS Attendance 5501"  >nul 2>&1
netsh advfirewall firewall delete rule name="Attendance Server"       >nul 2>&1
netsh advfirewall firewall add rule ^
    name="OwHAS Attendance 5501" ^
    dir=in ^
    action=allow ^
    protocol=TCP ^
    localport=5501 ^
    profile=any
if %errorlevel% equ 0 (
    echo       Port 5501 rule: ADDED  [profile=any]
) else (
    echo       WARNING: could not add port rule.
)

:: ── Firewall: allow node.exe inbound ───────────────────────────────────────
netsh advfirewall firewall delete rule name="Node.js Attendance" >nul 2>&1
for /f "delims=" %%N in ('where node 2^>nul') do (
    netsh advfirewall firewall add rule ^
        name="Node.js Attendance" ^
        dir=in ^
        action=allow ^
        program="%%N" ^
        profile=any
    if %errorlevel% equ 0 (
        echo       node.exe rule : ADDED  [%%N, profile=any]
    )
    goto :nodeRuleDone
)
:nodeRuleDone

:: ── [2/3] Download face-api.js and models (one-time, requires internet) ────
echo.
echo [2/3] Checking offline face recognition assets...

set "SHARD1=public\models\face_recognition_model-shard1"
if exist "public\lib\face-api.min.js" if exist "%SHARD1%" (
    for %%F in ("%SHARD1%") do set "SHARD_SIZE=%%~zF"
    if !SHARD_SIZE! GEQ 1000000 (
        echo       Assets already present and valid -- skipping download.
        goto :assetsReady
    ) else (
        echo       WARNING: Model shard is only !SHARD_SIZE! bytes ^(corrupt/incomplete^).
        echo       Deleting all model files and re-downloading...
        del /q "public\models\*" 2>nul
        del /q "public\lib\face-api.min.js" 2>nul
    )
)

echo       Assets missing. Downloading now (requires internet -- one-time only)...
echo       This takes ~30 seconds...
node setup.js
if %errorlevel% neq 0 (
    echo.
    echo       WARNING: Asset download failed. Face recognition will not work.
    echo       Check your internet connection and re-run this script before class.
    echo.
) else (
    echo       Download complete. Server will now run fully offline.
)

:assetsReady

:: ── [3/3] Start server ─────────────────────────────────────────────────────
echo.
echo [3/3] Starting server...
echo.
node server.js

echo.
echo Server exited.
pause
