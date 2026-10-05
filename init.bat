@echo off
rem ============================================================
rem  Cloudflare Pages Deployer - Environment Setup
rem  NOTE: keep this file ASCII-only. Non-ASCII bytes break
rem        cmd.exe parsing under GBK codepage.
rem ============================================================
setlocal enabledelayedexpansion
set "ROOT=%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "NEED_RESTART=0"

title Cloudflare Pages Deployer - Setup

echo ============================================================
echo   Cloudflare Pages Deployer - Setup
echo ============================================================
echo.
echo  This wizard checks and installs everything the tool needs.
echo  You do NOT need any tools installed in advance.
echo.
echo  Required components:
echo    1. PowerShell   - built into Windows 10/11
echo    2. Node.js      - installed automatically if missing
echo    3. wrangler     - installed automatically if missing
echo    4. A Cloudflare account - free, you will be guided
echo.

rem ---------- 0. proxy ----------
if defined HTTP_PROXY  echo [INFO] HTTP_PROXY  = %HTTP_PROXY%
if defined HTTPS_PROXY echo [INFO] HTTPS_PROXY = %HTTPS_PROXY%
if defined HTTP_PROXY  echo [INFO] Proxy detected. Slow downloads will use a mirror.
if defined HTTP_PROXY  echo.

rem ---------- 1. PowerShell ----------
echo [1/6] Checking PowerShell...
if not exist "%PS%" (
    echo   [ERROR] PowerShell not found at:
    echo           %PS%
    echo.
    echo   This tool requires Windows 10 or 11.
    echo   Windows 7 / 8 is not supported.
    echo.
    pause
    exit /b 1
)
echo   [OK] PowerShell is available.

rem ---------- 2. Node.js ----------
echo.
echo [2/6] Checking Node.js...
set "NODE_OK=0"
where node >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%v in ('node --version 2^>nul') do set "NODEV=%%v"
    echo   [OK] Node.js !NODEV!
    set "NODE_OK=1"
)

if "!NODE_OK!"=="0" (
    echo   [..] Node.js is missing. Attempting automatic install...
    echo.
    where winget >nul 2>&1
    if errorlevel 1 (
        echo   [WARN] winget is NOT available on this computer.
        echo.
        echo   Automatic install is not possible. Please install Node.js
        echo   manually ^(it takes about 2 minutes^):
        echo.
        echo       1. Open this link in your browser:
        echo          https://nodejs.org/en/download
        echo.
        echo       2. Download the "LTS" Windows Installer ^(.msi^)
        echo       3. Run the installer and click Next until finished
        echo       4. CLOSE this window, then run init.bat again
        echo.
        echo   If the link does not open, search for "Node.js download".
        echo.
        pause
        start "" "https://nodejs.org/en/download"
        exit /b 1
    )
    echo   [..] Installing Node.js LTS. This may take 1-3 minutes...
    echo.
    call winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo   [ERROR] Automatic installation failed.
        echo.
        echo   Please install Node.js manually ^(about 2 minutes^):
        echo       https://nodejs.org/en/download
        echo   Choose the "LTS" Windows Installer ^(.msi^).
        echo   Then CLOSE this window and run init.bat again.
        echo.
        pause
        start "" "https://nodejs.org/en/download"
        exit /b 1
    )
    echo.
    echo   [OK] Node.js has been installed.
    echo.
    echo   ============================================================
    echo    IMPORTANT - one more step
    echo   ============================================================
    echo    Node.js changed your system PATH. You must reopen this
    echo    window for it to take effect.
    echo.
    echo    1. CLOSE this window  ^(or press any key below^)
    echo    2. Run init.bat AGAIN
    echo.
    echo   ============================================================
    echo.
    pause
    exit /b 0
)

rem ---------- 3. npm ----------
echo.
echo [3/6] Checking npm...
where npm >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] npm is missing, but Node.js is installed.
    echo   Your Node.js installation looks broken.
    echo.
    echo   Please reinstall Node.js: https://nodejs.org/en/download
    echo.
    pause
    start "" "https://nodejs.org/en/download"
    exit /b 1
)
for /f "delims=" %%v in ('npm --version 2^>nul') do set "NPMV=%%v"
echo   [OK] npm !NPMV!

rem ---------- 4. wrangler ----------
echo.
echo [4/6] Checking wrangler CLI...
set "WR_OK=0"
where wrangler >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%v in ('wrangler --version 2^>nul') do set "WRV=%%v"
    echo   [OK] wrangler !WRV!
    set "WR_OK=1"
)

if "!WR_OK!"=="0" (
    echo   [..] wrangler is missing. Installing via npm...
    echo.
    set "INSTALL_CMD=npm install -g wrangler"
    if defined HTTP_PROXY set "INSTALL_CMD=npm install -g wrangler --registry=https://registry.npmmirror.com"
    call !INSTALL_CMD!
    if errorlevel 1 (
        echo.
        echo   [ERROR] wrangler installation failed.
        echo.
        echo   This is usually a network problem. Try:
        echo       npm config set registry https://registry.npmmirror.com
        echo       npm install -g wrangler
        echo.
        echo   If you are behind a company proxy, set:
        echo       set HTTPS_PROXY=http://your-proxy:port
        echo.
        pause
        exit /b 1
    )
    echo   [OK] wrangler installed.
    where wrangler >nul 2>&1
    if errorlevel 1 (
        echo.
        echo   [WARN] wrangler is installed but not in PATH yet.
        echo       Please CLOSE this window and run init.bat again.
        echo.
        pause
        exit /b 0
    )
)

rem ---------- 5. Cloudflare account ----------
echo.
echo [5/6] Checking Cloudflare account and login...
set "WHOAMI_FILE=%TEMP%\cf_whoami_%RANDOM%.txt"
call wrangler whoami >"!WHOAMI_FILE!" 2>&1
findstr /C:"logged in" "!WHOAMI_FILE!" >nul 2>&1
if errorlevel 1 goto :do_login
echo   [OK] Already logged in.
del "!WHOAMI_FILE!" >nul 2>&1
goto :final_check

:do_login
del "!WHOAMI_FILE!" >nul 2>&1
echo   [..] You are not logged in yet.
echo.
echo   ============================================================
echo    You need a Cloudflare account
echo   ============================================================
echo    A Cloudflare account is FREE and takes about 1 minute.
echo.
echo    Do you already have a Cloudflare account?
echo.
echo      [1] Yes, I have one  -^> continue to login
echo      [2] No,  I need one  -^> open the sign-up page first
echo      [3] Skip for now     -^> do it later from the GUI
echo.
set /p "HASACC=   Enter 1, 2 or 3: "

if "!HASACC!"=="2" (
    echo.
    echo   Opening the free sign-up page in your browser...
    start "" "https://dash.cloudflare.com/sign-up"
    echo.
    echo   Steps:
    echo     1. Enter your email and a password
    echo     2. Verify the email Cloudflare sends you
    echo     3. Come back here and press any key to continue
    echo.
    pause
    set "HASACC=1"
)

if "!HASACC!"=="3" (
    echo.
    echo   [SKIP] You can log in later:
    echo          run start.bat  -^>  click the "Login" button ^(bottom left^).
    echo.
    goto :final_check
)

echo.
echo   A browser window will now open for authorization.
echo   Click "Allow" to let this tool deploy to YOUR account.
echo.
pause
call wrangler login
if errorlevel 1 (
    echo.
    echo   [WARN] Login was not completed.
    echo          You can retry later from the GUI ^("Login" button^).
    echo          If the browser did not open, visit:
    echo              https://dash.cloudflare.com/profile/api-tokens
) else (
    echo   [OK] Logged in successfully.
)

:final_check
rem ---------- 6. final verification ----------
echo.
echo [6/6] Final verification...
set "FINAL_OK=1"
where node >nul 2>&1
if errorlevel 1 set "FINAL_OK=0"
where wrangler >nul 2>&1
if errorlevel 1 set "FINAL_OK=0"

if "!FINAL_OK!"=="0" (
    echo   [WARN] Some components are still missing.
    echo          Please run init.bat again.
    echo.
    pause
    exit /b 1
)

for /f "delims=" %%v in ('node --version 2^>nul') do set "NODEV=%%v"
for /f "delims=" %%v in ('wrangler --version 2^>nul') do set "WRV=%%v"
echo   [OK] Node.js   !NODEV!
echo   [OK] wrangler  !WRV!

echo.
echo ============================================================
echo   Setup complete.  Everything is ready.
echo.
echo   Next step:  double-click  start.bat
echo              or start-silent.vbs for no console window.
echo ============================================================
echo.
pause
exit /b 0
