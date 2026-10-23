# inventory-helper
Take note of your PC detectable components in a cool txt format to transfer it to any filetype you want

Execute the .bat to start analyzing and writing the components of your PC and be ready to copy it. This tool use the OS functions in powershell to automate this boring task.

## Uso

1. Copiar `INVENTARIO.bat`, `inventario.ps1` y (opcional) `persona.txt` a la PC. Correrlo desde el disco de la PC es mucho mas rapido que desde el USB.
2. Ejecutar `INVENTARIO.bat`, revisar lo detectado y completar **Sector** y **Observaciones** (Enter para dejarlos vacios).
3. El resultado queda en la carpeta `Inventario\<NOMBRE-PC>.txt`, junto a la fila lista para pegar en la planilla.

### persona.txt

Un archivo de texto con tu nombre en la primera linea. Si esta junto al script, se usa para la columna **Persona** sin preguntar nada.

### Que se detecta

- **Columnas de la fila:** usuario, motherboard, procesador, memoria, discos, DVD, monitores externos, impresora USB conectada, camara y sistema operativo. Si la webcam tiene microfono se anota en Observaciones.
- **Solo en el .txt (datos extra):** marca/modelo y numero de serie del equipo, tipo (notebook/escritorio), bateria, video, slots de RAM, espacio y salud de discos, IP/MAC, dominio, activacion de Windows, fechas de instalacion y BIOS, Office y antivirus.

Proyector, parlantes, mouse, teclado, UPS y microfono no se pueden detectar de forma confiable y quedan vacios.
