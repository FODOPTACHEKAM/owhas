@echo off
:: Start-Server.bat — launches the attendance Node server and opens Windows Firewall
:: Run this by double-clicking instead of typing "node server.js" manually.

echo ========================================
echo  Attendance Server Launcher
echo ========================================
echo.

:: Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH.
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

:: Add Windows Firewall rule for port 5501 (idempotent)
echo Checking Windows Firewall for port 5501...
netsh advfirewall firewall show rule name="Attendance Server" >nul 2>nul
if %errorlevel% neq 0 (
    echo Adding firewall rule for port 5501...
    netsh advfirewall firewall add rule name="Attendance Server" dir=in action=allow protocol=TCP localport=5501
    if %errorlevel% neq 0 (
        echo WARNING: Could not add firewall rule. Try running this batch file as Administrator.
    ) else (
        echo Firewall rule added successfully.
    )
) else (
    echo Firewall rule already exists.
)

echo.
echo Starting Node.js server...
echo.

:: Change to the script's directory so relative paths work
cd /d "%~dp0"

:: Start the server
node server.js

:: If the server exits, pause so the user can see any error messages
pause

