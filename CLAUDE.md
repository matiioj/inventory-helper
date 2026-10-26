# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A Windows-only PC hardware inventory tool. It detects a machine's components with PowerShell CIM queries and produces a human-readable `.txt` block plus a single tab-separated row that gets pasted into a spreadsheet (Google Sheets). User-facing text, variable names, and comments are in Spanish — keep it that way, and keep the `.ps1` ASCII-only (no accents): Windows PowerShell 5.1 reads BOM-less scripts as ANSI.

Real-world workflow: the user carries the files on a USB stick, copies them onto each PC in a building, runs the `.bat` there (running from the USB is too slow), and later collects the per-PC `.txt` files to paste rows into the sheet one by one. Design changes around that: no prompts beyond Sector and Observaciones, no state carried between PCs.

## Running

- `INVENTARIO.bat` — end-user entry point; sets UTF-8 console and runs the script with `-NoProfile -ExecutionPolicy Bypass`.
- Testing without the interactive prompts (stub `Read-Host`):
  `powershell -NoProfile -ExecutionPolicy Bypass -Command "function Read-Host { '' }; & '.\inventario.ps1'"`
  Run it from a copy outside the repo, since it writes an `Inventario/` folder next to the script.

No build, lint, or test suite.

## Architecture (`inventario.ps1`)

Linear script, one `# ---------- NAME ----------` section per field. Detection runs first, then a colored preview, then the two prompts, then output is written.

**The row format is a hard constraint.** `$campos` must stay 21 fields in the spreadsheet's column order: USUARIO, SECTOR, MOTHERBOARD, PROCESADOR, MEMORIA, DISCO, DVD, MONITOR, PROYECTOR, IMPRESORA, PARLANTES, MOUSE, TECLADO, UPS, MICROFONO, CAMARA, SO, OBSERVACIONES, PERSONA, FECHA, INSUMOS. Extra information goes only into the "DATOS EXTRA" section of the readable block, never into new columns. User inputs have tabs stripped so they can't shift columns.

Detection policy (agreed with the user): only fill a column if detection is reliable. Proyector, parlantes, mouse, teclado, UPS and microfono stay empty. Specifically:
- Monitor: `root\wmi` `WmiMonitorID` (EDID), excluding internal panels via `WmiMonitorConnectionParams.VideoOutputTechnology`.
- Impresora: only currently connected USB printers (`Win32_PnPEntity` with `DeviceID LIKE 'USBPRINT%'` — that class returns present devices only). No network/virtual/stale printers.
- Camara: `Service = 'usbvideo'`. A webcam mic (a `usbaudio` device with the same VID/PID) is noted in Observaciones as `CAMARA CON MICROFONO`.
- Disks use the `MSFT_PhysicalDisk` CIM class directly (numeric `MediaType`/`BusType`) instead of `Get-PhysicalDisk`, avoiding the slow Storage module load.

`Persona` comes from `persona.txt` (first line) next to the script (also accepts `persona*.txt`, e.g. `persona.txt.txt`; handles UTF-8/UTF-16/ANSI and BOM); it is never prompted. If empty, the final message says why.

## Output

Written to `Inventario/` next to the script: `<COMPUTERNAME>.txt` (readable block + row). There is no accumulated file.
