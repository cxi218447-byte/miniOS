@echo off
setlocal EnableExtensions
REM Usage in PowerShell or cmd (repo root):
REM   .\make.bat clean
REM   .\make.bat
REM   .\make.bat run

for /f "delims=" %%I in ('wsl -d Ubuntu wslpath -a "%~dp0."') do set "WSLDIR=%%I"
if not defined WSLDIR (
  echo [make.bat] failed to convert path via wslpath
  exit /b 1
)

if "%~1"=="" (
  wsl -d Ubuntu -- bash -lc "cd \"%WSLDIR%\" && make"
) else (
  wsl -d Ubuntu -- bash -lc "cd \"%WSLDIR%\" && make %*"
)
exit /b %ERRORLEVEL%
