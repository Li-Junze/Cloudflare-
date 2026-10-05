@echo off
rem ============================================================
rem  Cloudflare Pages Deployer - Smoke Test
rem  NOTE: keep this file ASCII-only.
rem ============================================================
setlocal
set "ROOT=%~dp0"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tests\smoke.ps1"
exit /b %errorlevel%
