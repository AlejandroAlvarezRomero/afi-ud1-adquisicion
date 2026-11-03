<#
.SYNOPSIS
    Respuesta en vivo ADAPTADA PARA WINDOWS 7 (PowerShell 2.0)
#>
param(
    [Parameter(Mandatory = $true)] [string] $Caso,
    [Parameter(Mandatory = $true)] [string] $Evidencia,
    [string] $Destino = "E:\salida"
)

$ErrorActionPreference = 'Continue'
$inicio  = Get-Date
$carpeta = Join-Path $Destino ("{0}_{1}_{2:yyyyMMdd-HHmmss}" -f $Caso, $Evidencia, $inicio.ToUniversalTime())
New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
$registro = Join-Path $carpeta '00-registro.txt'

function Escribe-Registro([string] $texto) {
    $linea = '{0:yyyy-MM-dd HH:mm:ss}Z  {1}' -f (Get-Date).ToUniversalTime(), $texto
    Add-Content -Path $registro -Value $linea -Encoding UTF8
    Write-Host $linea
}

function Recoge([string] $nombre, [scriptblock] $bloque) {
    $fichero = Join-Path $carpeta "$nombre.txt"
    Escribe-Registro "INICIO $nombre"
    try {
        $salida = & $bloque 2>&1 | Out-String -Width 4096
        Escribe-Registro "FIN    $nombre"
    } catch {
        $salida = "ERROR: $($_.Exception.Message)"
        Escribe-Registro "ERROR  $nombre : $($_.Exception.Message)"
    }
    Set-Content -Path $fichero -Value $salida -Encoding UTF8
}

Escribe-Registro "Caso $Caso · evidencia $Evidencia · equipo $env:COMPUTERNAME · usuario $env:USERDOMAIN\$env:USERNAME"

# --- 1. Estado del sistema y sesiones ---
Recoge '01-fecha-hora'        { Get-Date; wmic timezone get caption }
Recoge '01b-sincronizacion'   { w32tm /query /status }
Recoge '02-arranque'          { Get-WmiObject Win32_OperatingSystem | Select-Object CSName, Caption, Version, InstallDate, LastBootUpTime }
Recoge '03-sesiones'          { query user; Get-WmiObject Win32_LogonSession | Select-Object LogonId, LogonType, StartTime }

# --- 2. Red ---
Recoge '04-conexiones-tcp'    { netstat -ano | Select-String "TCP" }
Recoge '05-puertos-udp'       { netstat -ano | Select-String "UDP" }
Recoge '06-netstat'           { netstat -anob }
Recoge '07-cache-arp'         { arp -a }
Recoge '08-cache-dns'         { ipconfig /displaydns }
Recoge '09-rutas'             { route print }
Recoge '10-configuracion-red' { ipconfig /all }
Recoge '11-recursos-compartidos' { net share; net session; net use }

# --- 3. Procesos y servicios ---
Recoge '12-procesos'          { Get-WmiObject Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CreationDate, ExecutablePath, CommandLine | Format-List }
Recoge '13-servicios'         { Get-WmiObject Win32_Service | Select-Object Name, State, StartMode, StartName, PathName | Format-Table -AutoSize }
Recoge '14-tareas-programadas'{ schtasks /query /fo LIST /v }
Recoge '15-inicio-automatico' { Get-WmiObject Win32_StartupCommand | Select-Object Name, Command, Location, User | Format-List }

# --- 4. Usuarios, dispositivos y sistema ---
Recoge '16-usuarios-locales'  { Get-WmiObject Win32_UserAccount | Select-Object Name, Disabled, PasswordRequired, Lockout }
Recoge '16b-administradores'  { net localgroup Administradores }
Recoge '17-discos-volumenes'  { Get-WmiObject Win32_Volume | Select-Object Name, Label, FileSystem, Capacity, FreeSpace }
Recoge '18-usb-conectados'    { Get-WmiObject Win32_PnPEntity | Where-Object { $_.DeviceID -match 'USB' } | Select-Object Name, DeviceID, Status }
Recoge '19-portapapeles'      { try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetText() } catch { "Vacio o inaccesible" } }

# --- 5. Hash de todo lo generado usando criptografía .NET nativa ---
Escribe-Registro 'Calculando SHA-256 de los ficheros generados de forma nativa'
$excluidos = @('hashes-sha256.csv', '00-registro.txt')
$sha256 = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider

$resultadosHash = @()
Get-ChildItem -Path $carpeta | Where-Object { -not $_.PSIsContainer -and -not ($excluidos -contains $_.Name) } | ForEach-Object {
    $stream = [System.IO.File]::OpenRead($_.FullName)
    $hashBytes = $sha256.ComputeHash($stream)
    $stream.Close()
    $hashString = [System.BitConverter]::ToString($hashBytes).Replace('-','')
    
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name "Fichero" -Value $_.Name
    $obj | Add-Member -MemberType NoteProperty -Name "Hash" -Value $hashString
    $resultadosHash += $obj
}
$resultadosHash | Export-Csv -Path (Join-Path $carpeta 'hashes-sha256.csv') -NoTypeInformation -Encoding UTF8

$fin = Get-Date
Escribe-Registro ("Terminado en {0:N0} s. Salida: {1}" -f ($fin - $inicio).TotalSeconds, $carpeta)
Write-Host ''
Write-Host "Ejecucion completada con exito en entorno Legacy." -ForegroundColor Green