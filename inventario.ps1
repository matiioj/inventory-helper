$ErrorActionPreference = 'SilentlyContinue'
$outDir = Join-Path $PSScriptRoot 'Inventario'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Limpiar($t) { ($t -replace '\s+', ' ').Trim() }

$pc = $env:COMPUTERNAME

# ---------- SECTOR (no se puede detectar; Enter para dejarlo vacio) ----------
$sector = Read-Host "Sector de esta PC (Enter para dejar vacio)"

# ---------- MOTHERBOARD ----------
$bb  = Get-CimInstance Win32_BaseBoard
$fab = $bb.Manufacturer -replace '(?i)\b(technology|computer|international|corporation|corp|inc|co|ltd)\b\.?', '' -replace ',', ''
$mb  = (Limpiar "$fab $($bb.Product)").ToUpper()

# ---------- PROCESADOR ----------
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$cpu = $cpu -replace '\(R\)|\(TM\)|\(r\)|\(tm\)', ''
$cpu = $cpu -replace '(?i)\bwith .*$', '' -replace '@.*$', '' -replace '(?i)\bCPU\b', ''
$cpu = $cpu -replace '(?i)\b\w+-Core Processor', '' -replace '(?i)\bprocessor\b', ''
$cpu = (Limpiar $cpu) -replace '(?i)^(AMD|Intel) ', ''
$cpu = $cpu.ToUpper()

# ---------- MEMORIA ----------
$ram = @(Get-CimInstance Win32_PhysicalMemory)
$n   = $ram.Count
$tot = [math]::Round(($ram | Measure-Object Capacity -Sum).Sum / 1GB)
$por = [math]::Round($ram[0].Capacity / 1GB)
$tipoMap = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 34 = 'DDR5' }
$tipo  = $tipoMap[[int]$ram[0].SMBIOSMemoryType]
$marca = $ram[0].Manufacturer
if ($marca -match '^[0-9A-Fa-f]{4}$|Unknown|^0+$|^\s*$') { $marca = '' }
$vel = $ram[0].ConfiguredClockSpeed
if (-not $vel) { $vel = $ram[0].Speed }
$mem = "$tipo $marca $tot GB $($vel)Mhz"
if ($n -gt 1) { $mem += " (X$n $($por)GB)" }
$mem = Limpiar $mem

# ---------- DISCO ----------
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
$discos = @(Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' })
if ($discos.Count -gt 0) {
    foreach ($d in $discos) {
        $t = $d.MediaType
        if ($d.BusType -eq 'NVMe') { $t = 'SSD NVMe' }
        if ($t -eq 'Unspecified') { $t = '' }
        $m = Marca $d.FriendlyName
        $lista += Limpiar "$t $(Redondear $d.Size)GB $m ($($d.FriendlyName))"
    }
} else {
    foreach ($d in @(Get-CimInstance Win32_DiskDrive | Where-Object { $_.InterfaceType -ne 'USB' })) {
        $m = Marca $d.Model
        $lista += Limpiar "$(Redondear $d.Size)GB $m ($($d.Model))"
    }
}
$disco = $lista -join ' + '

# ---------- DVD ----------
$dvdDev = @(Get-CimInstance Win32_CDROMDrive | Where-Object { $_.Caption -notmatch 'Virtual|Msft|Mount' })
$dvd = if ($dvdDev.Count -gt 0) { 'SI' } else { 'NO' }

# ---------- SISTEMA OPERATIVO ----------
$os = Get-CimInstance Win32_OperatingSystem
$so = $os.Caption -replace 'Microsoft ', ''
if ([int]$os.BuildNumber -ge 22000) { $so = $so -replace 'Windows 10', 'Windows 11' }
$bits = $os.OSArchitecture -replace '[^0-9]', ''
$so = (Limpiar "$so $($bits)BITS").ToUpper()

# ---------- FECHA ----------
$fecha = (Get-Date).ToString("d'/'MM'/'yy")

# ---------- FILA PARA PEGAR (desde USUARIO hasta INSUMOS, separada por TAB) ----------
$campos = @($pc, $sector, $mb, $cpu, $mem, $disco, $dvd) +
          (@('') * 9) +                    # monitor, proyector, impresora, parlantes, mouse, teclado, UPS, microfono, camara
          @($so, '', '', $fecha, '')       # SO, observaciones, persona, fecha, insumos
$fila = $campos -join "`t"

# ---------- LOG LEGIBLE ----------
$bloque = @"
==================================================
 INVENTARIO - $pc   ($fecha)
==================================================
USUARIO      : $pc
SECTOR       : $sector
MOTHERBOARD  : $mb
PROCESADOR   : $cpu
MEMORIA      : $mem
DISCO        : $disco
DVD          : $dvd
SIST. OPER.  : $so
FECHA        : $fecha
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

Write-Host $bloque
Write-Host ""
Write-Host "Guardado en: $outDir\$pc.txt" -ForegroundColor Green
