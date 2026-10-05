@echo off
rem ============================================================
rem  Cloudflare Pages Deployer - Launcher
rem  NOTE: keep this file ASCII-only. Non-ASCII bytes break
rem        cmd.exe parsing under GBK codepage.
rem ============================================================
setlocal enabledelayedexpansion
set "ROOT=%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

title Cloudflare Pages Deployer

rem ---------- preflight checks (so errors are visible, not silent) ----------
set "PROBLEM="

if not exist "%ROOT%src\main.ps1" set "PROBLEM=src\main.ps1 is missing (incomplete extraction?)"
if not exist "%PS%" set "PROBLEM=PowerShell not found (Windows 10/11 required)"

if not defined PROBLEM (
    where node >nul 2>&1
    if errorlevel 1 set "PROBLEM=Node.js is not installed"
)
if not defined PROBLEM (
    where wrangler >nul 2>&1
    if errorlevel 1 set "PROBLEM=wrangler is not installed"
)

if defined PROBLEM goto :need_setup
goto :launch

:need_setup
echo.
echo ============================================================
echo   Cannot start - a required component is missing
echo ============================================================
echo.
echo   Reason: !PROBLEM!
echo.
echo   Running init.bat will install everything automatically.
echo.
echo ============================================================
echo.
echo   Press any key to run init.bat, or close this window to cancel.
echo.
pause >nul

if exist "%ROOT%init.bat" (
    call "%ROOT%init.bat"
) else (
    echo.
    echo   [ERROR] init.bat is also missing.
    echo           The download may be incomplete. Please re-download.
    echo.
    pause
)
exit /b 1

:launch
rem ---------- launch ----------
rem -STA is required for WPF.
start "" "%PS%" -NoProfile -STA -ExecutionPolicy Bypass -File "%ROOT%src\main.ps1" %*

rem Give the GUI a few seconds to appear.
ping -n 5 127.0.0.1 >nul 2>&1

rem Verify the window actually exists by looking for a PowerShell process
rem that has a visible main window (the GUI itself).
set "GUI_FOUND="
for /f "usebackq tokens=*" %%i in (`"%PS%" -NoProfile -Command "if (Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }) { 'yes' } else { 'no' }"`) do set "GUI_FOUND=%%i"

if /I "!GUI_FOUND!"=="yes" exit /b 0

echo.
echo ============================================================
echo   The window did not open
echo ============================================================
echo.
echo   PowerShell started but no window appeared. Common causes:
echo.
echo     - Antivirus / security software blocking PowerShell scripts
echo     - PowerShell execution policy restrictions
echo     - A PowerShell profile that throws an error
echo.
echo   To see the exact error, open a command prompt and run:
echo.
echo     "%PS%" -NoProfile -STA -ExecutionPolicy Bypass -File "%ROOT%src\main.ps1"
echo.
echo ============================================================
echo.
pause
exit /b 1
