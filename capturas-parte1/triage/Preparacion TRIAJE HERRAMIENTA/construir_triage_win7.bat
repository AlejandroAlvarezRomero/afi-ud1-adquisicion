@echo off
rem ==========================================================================
rem  Prepara la carpeta PARA_LA_VM  (se ejecuta en TU ORDENADOR, no en la VM)
rem  Ya NO descarga nada de GitHub: usa un "generic collector".
rem
rem  Esta carpeta debe contener estos 6 ficheros:
rem    1) construir_triage_win7.bat          (este)
rem    2) lanzar_triage.bat
rem    3) triage_win7_spec.yaml
rem    4) velociraptor-v0.76.7-windows-amd64.exe
rem    5) velociraptor-v0.76.1-windows-amd64-legacy.exe  (o ...-386-legacy.exe)
rem    6) Velociraptor_Triage_v0.1.zip
rem ==========================================================================
setlocal EnableExtensions
cd /d "%~dp0"

set "BUILD_VER=0.76.7"
set "LEGACY_VER=0.76.1"
set "LEGACY_TAG=v0.76"

echo.
choice /c SN /m "Tu Windows 7 es de 64 bits (S) o de 32 bits (N)"
if errorlevel 2 (
  set "ARCH=386"
) else (
  set "ARCH=amd64"
)

set "BUILDER=velociraptor-v%BUILD_VER%-windows-amd64.exe"
set "LEGACY=velociraptor-v%LEGACY_VER%-windows-%ARCH%-legacy.exe"
set "SPEC=triage_win7_spec.yaml"
set "TRIAGE_ZIP=Velociraptor_Triage_v0.1.zip"
set "LAUNCHER=lanzar_triage.bat"
set "OUTDIR=PARA_LA_VM"

set "FALTA=0"
echo.
if not exist "%BUILDER%" (
  echo [FALTA] %BUILDER%
  echo         Bajalo de: https://github.com/Velocidex/velociraptor/releases/download/v%BUILD_VER%/%BUILDER%
  set "FALTA=1"
)
if not exist "%LEGACY%" (
  echo [FALTA] %LEGACY%
  echo         Bajalo de: https://github.com/Velocidex/velociraptor/releases/download/%LEGACY_TAG%/%LEGACY%
  set "FALTA=1"
)
if not exist "%TRIAGE_ZIP%" (
  echo [FALTA] %TRIAGE_ZIP%
  echo         Bajalo de: https://triage.velocidex.com/artifacts/%TRIAGE_ZIP%
  set "FALTA=1"
)
if not exist "%SPEC%" (
  echo [FALTA] %SPEC%  ^(es el que te di yo; ponlo junto a este .bat^)
  set "FALTA=1"
)
if not exist "%LAUNCHER%" (
  echo [FALTA] %LAUNCHER%  ^(es el que te di yo; ponlo junto a este .bat^)
  set "FALTA=1"
)
if "%FALTA%"=="1" (
  echo.
  echo Descarga lo que falta, ponlo en esta carpeta y vuelve a ejecutar.
  pause
  exit /b 1
)

echo [1/3] Preparando las definiciones de Windows.Triage.Targets...
if not exist artifacts mkdir artifacts
tar -xf "%TRIAGE_ZIP%" -C artifacts >nul 2>&1
if errorlevel 1 (
  echo [AVISO] No pude descomprimir automaticamente.
  echo         Haz clic derecho en %TRIAGE_ZIP% ^> Extraer todo...
  echo         y elige como destino la carpeta "artifacts" de esta misma carpeta.
  pause
)

echo.
echo [2/3] Construyendo el collector con el spec...
echo.
if exist datastore rmdir /s /q datastore
mkdir datastore
"%BUILDER%" collector --datastore datastore --definitions artifacts "%SPEC%"
set "RC=%ERRORLEVEL%"
echo.
echo [Codigo de salida del paso 2: %RC%]
if not "%RC%"=="0" (
  echo [!] PASO 2/3 fallo. Hazme una captura de las ultimas lineas de arriba.
  pause
  exit /b 1
)

set "COL="
for %%f in (datastore\Collector_*) do set "COL=%%f"
if not defined COL (
  echo [!] PASO 2/3: termino sin error pero no encuentro el Collector_* en datastore.
  echo     Esto es lo que hay en datastore:
  dir datastore
  pause
  exit /b 1
)

echo.
echo [3/3] Montando la carpeta %OUTDIR%...
if exist "%OUTDIR%" rmdir /s /q "%OUTDIR%"
mkdir "%OUTDIR%"
copy /y "%LEGACY%" "%OUTDIR%\velociraptor_win7.exe" >nul
copy /y "%COL%" "%OUTDIR%\triage.collector" >nul
copy /y "%LAUNCHER%" "%OUTDIR%\lanzar_triage.bat" >nul
if errorlevel 1 (
  echo [!] PASO 3/3: no pude copiar los ficheros a %OUTDIR%.
  pause
  exit /b 1
)

echo.
echo [LISTO] Carpeta creada: %~dp0%OUTDIR%
echo         Copia TODO su contenido ^(3 ficheros^) al segundo disco de la VM.
dir "%OUTDIR%"
pause
endlocal
exit /b 0
