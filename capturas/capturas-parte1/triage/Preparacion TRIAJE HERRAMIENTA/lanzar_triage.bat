@echo off
rem ==========================================================================
rem  Lanzador para la VM Windows 7. Debe estar en la MISMA carpeta que
rem    - velociraptor_win7.exe
rem    - triage.collector
rem  Ejecutalo con "Ejecutar como administrador".
rem  El ZIP del triage y el manifiesto YAML se guardan en esta misma carpeta.
rem ==========================================================================
setlocal EnableExtensions
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
  echo [!] Ejecuta este archivo como Administrador.
  pause
  exit /b 1
)

set "VELO=velociraptor_win7.exe"
set "COLLECTOR=triage.collector"
if not exist "%VELO%" (
  echo [!] No encuentro %VELO% en %~dp0
  pause
  exit /b 1
)
if not exist "%COLLECTOR%" (
  echo [!] No encuentro %COLLECTOR% en %~dp0
  pause
  exit /b 1
)

set "T0="
for /f "skip=1 tokens=1" %%a in ('wmic os get localdatetime') do if not defined T0 set "T0=%%a"

"%VELO%" -- --embedded_config "%COLLECTOR%"
set "RC=%ERRORLEVEL%"

set "T1="
for /f "skip=1 tokens=1" %%a in ('wmic os get localdatetime') do if not defined T1 set "T1=%%a"

set "OSV="
for /f "tokens=*" %%v in ('ver') do set "OSV=%%v"

set "MANIFEST=triage_manifest_%COMPUTERNAME%_%T0:~0,14%.yaml"

> "%MANIFEST%"  echo # Manifiesto de la ejecucion del triage
>> "%MANIFEST%" echo host: "%COMPUTERNAME%"
>> "%MANIFEST%" echo user: "%USERNAME%"
>> "%MANIFEST%" echo os: "%OSV%"
>> "%MANIFEST%" echo command: "%VELO% -- --embedded_config %COLLECTOR%"
>> "%MANIFEST%" echo start_local: "%T0:~0,14%"
>> "%MANIFEST%" echo end_local: "%T1:~0,14%"
>> "%MANIFEST%" echo exit_code: %RC%
>> "%MANIFEST%" echo outputs:
for %%f in (Triage-*.zip) do >> "%MANIFEST%" echo   - {file: "%%f", size_bytes: %%~zf}

echo.
echo [OK] Manifiesto escrito en %~dp0%MANIFEST%
pause
endlocal
