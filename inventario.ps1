$ErrorActionPreference = 'SilentlyContinue'
$outDir = Join-Path $PSScriptRoot 'Inventario'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Limpiar($t) { ($t -replace '\s+', ' ').Trim() }
function SinMarcas($t) { Limpiar ($t -replace '\(R\)|\(TM\)|\(r\)|\(tm\)', '') }
function Linea($etq, $val) { if (-not $val) { $val = '-' }; '{0,-13}: {1}' -f $etq, $val }
$basura = '(?i)^\s*(to be filled.*|default string|system (serial number|product name|manufacturer)|none|n/?a|not applicable|o\.?e\.?m\.?|0+|\.)?\s*$'

# ---------- CONSOLA (caracteres de dibujo armados con [char] para que el .ps1 siga siendo ASCII) ----------
$H = [string][char]0x2550; $V = [char]0x2551; $Hf = [string][char]0x2500
$lleno = [string][char]0x2588; $vacio = [string][char]0x2591
$script:pasoN = 0; $pasosTotal = 11

function Paso($t) {
    $script:pasoN++
    $n = [int](30 * $script:pasoN / $pasosTotal)
    Write-Host ("`r   Analizando  " + $lleno * $n + $vacio * (30 - $n) + ('  {0,-22}' -f $t)) -NoNewline -ForegroundColor Cyan
}
function Seccion($titulo) {
    Write-Host ""
    Write-Host ("   " + $Hf * 2 + " $titulo " + $Hf * (52 - $titulo.Length)) -ForegroundColor Cyan
}
function Mostrar($etq, $val) {
    if ($etq -eq 'BATERIA' -and -not $val) { return }
    Write-Host ('    {0,-14}' -f $etq) -NoNewline -ForegroundColor DarkGray
    if (-not $val) { Write-Host 'no detectado' -ForegroundColor DarkYellow; return }
    $partes = @($val -split ' \+ | \| ')
    Write-Host $partes[0] -ForegroundColor White
    $partes | Select-Object -Skip 1 | ForEach-Object { Write-Host (' ' * 18 + $_) -ForegroundColor White }
}
function Preguntar($etq) {
    Write-Host ('    {0,-14}' -f $etq) -NoNewline -ForegroundColor Yellow
    Limpiar ((Read-Host) -replace "`t", ' ')
}

$pc    = $env:COMPUTERNAME
$fecha = (Get-Date).ToString("d'/'MM'/'yy")

Clear-Host
$titulo = "INVENTARIO DE PC   $pc   $fecha"
Write-Host ""
Write-Host ("   " + [char]0x2554 + $H * 56 + [char]0x2557) -ForegroundColor Cyan
Write-Host ("   $V" + ('  {0,-54}' -f $titulo) + $V) -ForegroundColor Cyan
Write-Host ("   " + [char]0x255A + $H * 56 + [char]0x255D) -ForegroundColor Cyan
Write-Host ""

# ---------- PERSONA (se lee de persona.txt junto al script, no se pregunta) ----------
$persona = ''
$personaTxt = Join-Path $PSScriptRoot 'persona.txt'
if (Test-Path $personaTxt) {
    $persona = Limpiar ((Get-Content $personaTxt | Where-Object { $_.Trim() } | Select-Object -First 1) -replace "`t", ' ')
}

# ---------- MOTHERBOARD ----------
Paso 'Motherboard'
$bb  = Get-CimInstance Win32_BaseBoard
$fab = $bb.Manufacturer -replace '(?i)\b(technology|computer|international|corporation|corp|inc|co|ltd)\b\.?', '' -replace ',', ''
$mb  = (Limpiar "$fab $($bb.Product)").ToUpper()

# ---------- PROCESADOR ----------
Paso 'Procesador'
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$cpu = $cpu -replace '\(R\)|\(TM\)|\(r\)|\(tm\)', ''
$cpu = $cpu -replace '(?i)\bwith .*$', '' -replace '@.*$', '' -replace '(?i)\bCPU\b', ''
$cpu = $cpu -replace '(?i)\b\w+-Core Processor', '' -replace '(?i)\bprocessor\b', ''
$cpu = (Limpiar $cpu) -replace '(?i)^(AMD|Intel) ', ''
$cpu = $cpu.ToUpper()

# ---------- MEMORIA ----------
Paso 'Memoria'
$ram = @(Get-CimInstance Win32_PhysicalMemory)
$n   = $ram.Count
$mem = ''
if ($n -gt 0) {
    $tot = [math]::Round(($ram | Measure-Object Capacity -Sum).Sum / 1GB)
    $por = [math]::Round($ram[0].Capacity / 1GB)
    $tipoMap = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 34 = 'DDR5' }
    $tipo  = $tipoMap[[int]$ram[0].SMBIOSMemoryType]
    if (-not $tipo) { $tipo = $tipoMap[[int]$ram[0].MemoryType] }   # PCs viejas
    $marca = $ram[0].Manufacturer
    if ($marca -match '^[0-9A-Fa-f]{4}$|Unknown|^0+$|^\s*$') { $marca = '' }
    $vel = $ram[0].ConfiguredClockSpeed
    if (-not $vel) { $vel = $ram[0].Speed }
    $mem = "$tipo $marca $tot GB"
    if ($vel) { $mem += " $($vel)Mhz" }
    if ($n -gt 1) { $mem += " (X$n $($por)GB)" }
    $mem = Limpiar $mem
}

# ---------- DISCO ----------
Paso 'Discos'
$tamanos = 60,120,128,240,250,256,480,500,512,960,1000,1024,2000,4000
function Redondear($bytes) {
    $gb = $bytes / 1e9
    $tamanos | Sort-Object { [math]::Abs($_ - $gb) } | Select-Object -First 1
}
function Marca($modelo) {
    switch -Regex ($modelo) {
        '^CT\d|Crucial'          { return 'Crucial' }
        '^WDC|^WD'               { return 'Western Digital' }
        '^ST\d'                  { return 'Seagate' }
        'Kingston|^SA400|^SKC'   { return 'Kingston' }
        'Samsung|^MZ'            { return 'Samsung' }
        default                  { return '' }
    }
}
$lista = @()
$salud = @()
# Se consulta la clase CIM directo: Get-PhysicalDisk carga el modulo Storage y es mas lento
$discos = @(Get-CimInstance -Namespace root/Microsoft/Windows/Storage -ClassName MSFT_PhysicalDisk |
            Where-Object { $_.BusType -ne 7 })   # 7 = USB
if ($discos.Count -gt 0) {
    $mediaMap  = @{ 3 = 'HDD'; 4 = 'SSD' }
    $saludMap  = @{ 0 = 'OK'; 1 = 'ADVERTENCIA'; 2 = 'FALLANDO' }
    foreach ($d in $discos) {
        $t = $mediaMap[[int]$d.MediaType]
        if ($d.BusType -eq 17) { $t = 'SSD NVMe' }   # 17 = NVMe
        $m = Marca $d.FriendlyName
        $lista += Limpiar "$t $(Redondear $d.Size)GB $m ($($d.FriendlyName))"
        $salud += "$($d.FriendlyName.Trim()): $($saludMap[[int]$d.HealthStatus])"
    }
} else {
    foreach ($d in @(Get-CimInstance Win32_DiskDrive | Where-Object { $_.InterfaceType -ne 'USB' })) {
        $m = Marca $d.Model
        $lista += Limpiar "$(Redondear $d.Size)GB $m ($($d.Model))"
    }
}
$disco = $lista -join ' + '
$espacio = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.Size -gt 1GB } | ForEach-Object {
    "$($_.DeviceID) $([math]::Round($_.FreeSpace / 1GB)) GB libres de $([math]::Round($_.Size / 1GB)) GB"
}) -join ' | '

# ---------- DVD ----------
Paso 'Lectora DVD'
$dvdDev = @(Get-CimInstance Win32_CDROMDrive | Where-Object { $_.Caption -notmatch 'Virtual|Msft|Mount' })
$dvd = if ($dvdDev.Count -gt 0) { 'SI' } else { 'NO' }

# ---------- MONITOR (solo externos; la pantalla de una notebook no cuenta) ----------
Paso 'Monitores'
$marcasMon = @{ SAM='SAMSUNG'; SEC='SAMSUNG'; GSM='LG'; DEL='DELL'; ACR='ACER'; AOC='AOC'; HWP='HP'; HPN='HP';
                PHL='PHILIPS'; BNQ='BENQ'; LEN='LENOVO'; VSC='VIEWSONIC'; AUS='ASUS'; ACI='ASUS'; SNY='SONY';
                NEC='NEC'; HKC='HKC'; HSD='HANNSPREE'; HSP='HANNSPREE'; IVM='IIYAMA'; MSI='MSI'; GBT='GIGABYTE'; SHP='SHARP' }
$internas = @(6, 11, 13, 2147483648, -2147483648)   # LVDS, DP embebido, UDI embebido, interna
$conexion = @{}
Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams |
    ForEach-Object { $conexion[$_.InstanceName] = $_.VideoOutputTechnology }
$monitores = @()
foreach ($mo in @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | Where-Object { $_.Active })) {
    if ($internas -contains $conexion[$mo.InstanceName]) { continue }
    $nombre = (($mo.UserFriendlyName | Where-Object { $_ }) | ForEach-Object { [char]$_ }) -join ''
    $cod    = (($mo.ManufacturerName | Where-Object { $_ }) | ForEach-Object { [char]$_ }) -join ''
    $fabMon = $marcasMon[$cod]
    if (-not $fabMon) { $fabMon = $cod }
    if ($nombre -notmatch [regex]::Escape($fabMon)) { $nombre = "$fabMon $nombre" }
    $monitores += (Limpiar $nombre).ToUpper()
}
$monitor = $monitores -join ' + '

# ---------- DISPOSITIVOS USB CONECTADOS (impresora, camara) ----------
# Win32_PnPEntity solo devuelve dispositivos presentes, asi que una impresora
# que se instalo hace anios y ya no esta enchufada no aparece.
Paso 'Impresora y camara'
$usb = @(Get-CimInstance -Query "SELECT Name,DeviceID,Service FROM Win32_PnPEntity WHERE DeviceID LIKE 'USB%'")
$impresora = (@($usb | Where-Object { $_.DeviceID -like 'USBPRINT\*' } | ForEach-Object { SinMarcas $_.Name }) |
              Select-Object -Unique) -join ' + '
$camaras = @($usb | Where-Object { $_.Service -eq 'usbvideo' })
$camara  = (@($camaras | ForEach-Object { SinMarcas $_.Name }) | Select-Object -Unique) -join ' + '

# Microfono de la webcam: un dispositivo de audio con el mismo VID/PID que la camara
$notas = @()
foreach ($c in $camaras) {
    if ($c.DeviceID -match '^USB\\(VID_[0-9A-F]{4}&PID_[0-9A-F]{4})') {
        $id = $Matches[1]
        if ($usb | Where-Object { $_.DeviceID -like "USB\$id*" -and $_.Service -eq 'usbaudio' }) {
            $notas += 'CAMARA CON MICROFONO'
            break
        }
    }
}

# ---------- SISTEMA OPERATIVO ----------
Paso 'Sistema operativo'
$os = Get-CimInstance Win32_OperatingSystem
$so = $os.Caption -replace 'Microsoft ', ''
if ([int]$os.BuildNumber -ge 22000) { $so = $so -replace 'Windows 10', 'Windows 11' }
$bits = $os.OSArchitecture -replace '[^0-9]', ''
$so = (Limpiar "$so $($bits)BITS").ToUpper()

# ---------- DATOS EXTRA (solo para el bloque legible, no van en la fila) ----------
Paso 'Datos extra'
$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS

$equipo = ''
if ($cs.Model -notmatch $basura) {
    $fabEq  = $cs.Manufacturer -replace '(?i)\b(inc|corporation|corp|co|ltd)\b\.?', '' -replace ',', ''
    $fabEq  = Limpiar $fabEq
    $equipo = if ($cs.Model -match "^$([regex]::Escape($fabEq))\b") { $cs.Model } else { "$fabEq $($cs.Model)" }
    $equipo = (Limpiar $equipo).ToUpper()
}
$serie = $bios.SerialNumber
if ($serie -match $basura) { $serie = $bb.SerialNumber }
if ($serie -match $basura) { $serie = '' }
$serie = Limpiar $serie

$portatiles = 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
$chasis = @((Get-CimInstance Win32_SystemEnclosure).ChassisTypes)
$esNotebook = [bool]($chasis | Where-Object { $portatiles -contains $_ })
$tipoEq = if ($esNotebook) { 'NOTEBOOK' } else { 'ESCRITORIO' }

$bateria = ''
if ($esNotebook) {
    $full   = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity | Select-Object -First 1).FullChargedCapacity
    $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData | Select-Object -First 1).DesignedCapacity
    if ($full -and $design) { $bateria = "$([math]::Round($full * 100 / $design))% de la capacidad original" }
}

$video = (@(Get-CimInstance Win32_VideoController |
            Where-Object { $_.Name -notmatch '(?i)basic|remote|virtual|mirror|indirect' } |
            ForEach-Object { SinMarcas $_.Name }) | Select-Object -Unique) -join ' + '

$arr = Get-CimInstance Win32_PhysicalMemoryArray | Where-Object { $_.Use -eq 3 } | Select-Object -First 1
$slots = ''
if ($arr.MemoryDevices) {
    $slots = "$n de $($arr.MemoryDevices) ocupados"
    if ($arr.MaxCapacityEx) { $slots += " (max $([math]::Round($arr.MaxCapacityEx / 1MB)) GB)" }
}

$red = (@(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' |
          Where-Object { $_.DefaultIPGateway } | ForEach-Object {
              "$(@($_.IPAddress | Where-Object { $_ -match '^\d+\.' })[0]) (MAC $($_.MACAddress -replace ':', '-'))"
          })) -join ' | '
$dominio = if ($cs.PartOfDomain) { "DOMINIO $($cs.Domain)" } else { "GRUPO DE TRABAJO $($cs.Workgroup)" }

Paso 'Licencia de Windows'
$lic = Get-CimInstance SoftwareLicensingProduct -Property LicenseStatus `
       -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL"
$activacion = if (@($lic | Where-Object { $_.LicenseStatus -eq 1 }).Count -gt 0) { 'ACTIVADO' } elseif ($lic) { 'NO ACTIVADO' } else { '' }

$instalado = if ($os.InstallDate) { $os.InstallDate.ToString('dd/MM/yyyy') } else { '' }
$fechaBios = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('dd/MM/yyyy') } else { '' }

Paso 'Office y antivirus'
$office = (@(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
             Where-Object { $_.DisplayName -match '^Microsoft (Office|365)' -and
                            $_.DisplayName -notmatch '(?i)proof|mui|language|idioma|extensib|licens|component|shared|update|click-to-run|viewer|engine|validation' } |
             ForEach-Object { $_.DisplayName -replace '\s+-\s+[a-z]{2}-[a-z]{2}$', '' } |
             Where-Object { $_ -notmatch ' - ' }) | Select-Object -Unique) -join ' + '   # lo que queda con " - " son paquetes de idioma

# productState: el segundo byte en 0x10/0x11 significa que el antivirus esta activo
$antivirus = (@(Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct |
                Where-Object { ('{0:X6}' -f $_.productState).Substring(2, 2) -in '10', '11' } |
                ForEach-Object { $_.displayName }) | Select-Object -Unique) -join ' + '

# ---------- PANTALLA ----------
Write-Host ("`r   Analizando  " + $lleno * 30 + ('  {0,-22}' -f 'listo')) -ForegroundColor Green

Seccion 'EQUIPO'
Mostrar 'Modelo' $equipo
Mostrar 'N. de serie' $serie
Mostrar 'Tipo' $tipoEq
Mostrar 'BATERIA' $bateria

Seccion 'HARDWARE'
Mostrar 'Motherboard' $mb
Mostrar 'Procesador' $cpu
Mostrar 'Memoria' $mem
Mostrar 'Slots RAM' $slots
Mostrar 'Video' $video
Mostrar 'Discos' $disco
Mostrar 'Salud' ($salud -join ' | ')
Mostrar 'Espacio' $espacio
Mostrar 'DVD' $dvd

Seccion 'PERIFERICOS'
Mostrar 'Monitor' $monitor
Mostrar 'Impresora' $impresora
Mostrar 'Camara' $camara
if ($notas) { Mostrar 'Nota' ($notas -join ' - ') }

Seccion 'SISTEMA'
Mostrar 'Windows' $so
Mostrar 'Licencia' $activacion
Mostrar 'Instalado' $instalado
Mostrar 'Fecha BIOS' $fechaBios
Mostrar 'Office' $office
Mostrar 'Antivirus' $antivirus
Mostrar 'Red' $red
Mostrar 'Red local' $dominio

Seccion 'COMPLETAR  (Enter = dejar vacio)'
$sector = Preguntar 'Sector'
$obs    = Preguntar 'Observaciones'
if ($obs) { $notas += $obs }
$observaciones = $notas -join ' - '

# ---------- FILA PARA PEGAR (desde USUARIO hasta INSUMOS, separada por TAB) ----------
$campos = @($pc, $sector, $mb, $cpu, $mem, $disco, $dvd,
            $monitor, '', $impresora, '', '', '', '', '', $camara,   # monitor, proyector, impresora, parlantes, mouse, teclado, UPS, microfono, camara
            $so, $observaciones, $persona, $fecha, '')               # SO, observaciones, persona, fecha, insumos
$fila = $campos -join "`t"

# ---------- LOG LEGIBLE ----------
$principal = @(
    (Linea 'USUARIO' $pc), (Linea 'SECTOR' $sector), (Linea 'MOTHERBOARD' $mb), (Linea 'PROCESADOR' $cpu),
    (Linea 'MEMORIA' $mem), (Linea 'DISCO' $disco), (Linea 'DVD' $dvd), (Linea 'MONITOR' $monitor),
    (Linea 'IMPRESORA' $impresora), (Linea 'CAMARA' $camara), (Linea 'SIST. OPER.' $so),
    (Linea 'OBSERVACION.' $observaciones), (Linea 'PERSONA' $persona), (Linea 'FECHA' $fecha)
) -join "`r`n"
$extra = @(
    (Linea 'EQUIPO' $equipo), (Linea 'N. DE SERIE' $serie), (Linea 'TIPO' $tipoEq)
    if ($bateria) { Linea 'BATERIA' $bateria }   # Windows a veces solo la informa con permisos de administrador
    (Linea 'VIDEO' $video), (Linea 'SLOTS RAM' $slots), (Linea 'ESPACIO' $espacio),
    (Linea 'SALUD DISCO' ($salud -join ' | ')), (Linea 'RED' $red), (Linea 'RED LOCAL' $dominio),
    (Linea 'WINDOWS' $activacion), (Linea 'INSTALADO' $instalado), (Linea 'FECHA BIOS' $fechaBios),
    (Linea 'OFFICE' $office), (Linea 'ANTIVIRUS' $antivirus)
) -join "`r`n"

$bloque = @"
==================================================
 INVENTARIO - $pc   ($fecha)
==================================================
$principal
------------------ DATOS EXTRA -------------------
$extra
--------------------------------------------------
FILA PARA PEGAR EN LA PLANILLA (pegar en la celda USUARIO):
$fila
==================================================
"@

Set-Content -Path (Join-Path $outDir "$pc.txt") -Value $bloque -Encoding UTF8

# Archivo acumulado: una fila por PC (si ya estaba, se reemplaza)
$todas = Join-Path $outDir 'TODAS_LAS_FILAS.txt'
$prev = @()
if (Test-Path $todas) {
    $prev = @(Get-Content $todas | Where-Object { $_ -and -not $_.StartsWith("$pc`t") })
}
Set-Content -Path $todas -Value ($prev + $fila) -Encoding UTF8

Write-Host ""
Write-Host "    GUARDADO " -NoNewline -ForegroundColor Black -BackgroundColor Green
Write-Host "  $outDir\$pc.txt" -ForegroundColor Gray
if (-not $persona) { Write-Host "    (sin persona.txt: la columna Persona queda vacia)" -ForegroundColor DarkGray }
Write-Host ""
Write-Host "    Presione una tecla para cerrar..." -ForegroundColor DarkGray
