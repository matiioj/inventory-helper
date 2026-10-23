# inventory-helper
Take note of your PC detectable components in a cool txt format to transfer it to any filetype you want

Execute the .bat to start analyzing and writing the components of your PC and be ready to copy it. This tool use the OS functions in powershell to automate this boring task.

## Uso

1. Copiar `INVENTARIO.bat` e `inventario.ps1` a la PC, **a la misma carpeta**. Si hay `persona.txt`, tambien va en esa carpeta. Correrlo desde el disco de la PC es mucho mas rapido que desde el USB.
2. Ejecutar `INVENTARIO.bat`. Revisar lo detectado y completar **Sector** y **Observaciones** (Enter para dejarlos vacios).
3. El resultado queda en la carpeta `Inventario\` que se crea junto al script:
   - `Inventario\<NOMBRE-PC>.txt`: bloque legible + la fila para pegar en la planilla.
   - `Inventario\TODAS_LAS_FILAS.txt`: solo la fila de esa PC.
4. Despues, copiar la fila (la linea que empieza con el nombre de la PC) y pegarla en la celda USUARIO de la planilla.

### persona.txt (opcional)

- Va en la **misma carpeta que `inventario.ps1`**, no en una subcarpeta. Si el script esta en la raiz del USB, el archivo tambien va en la raiz.
- Se lee solo la **primera linea**, con el nombre de quien hace el inventario.
- Si no existe, no se pregunta nada: la columna **Persona** queda vacia.
- Hay que copiarlo a la PC junto con el script. Si no, en esa PC la columna queda vacia.

### Que se detecta

- **Columnas de la fila:** usuario, motherboard, procesador, memoria, discos, DVD, monitor externo, impresora USB, camara y sistema operativo. Si la webcam tiene microfono se anota en Observaciones como `CAMARA CON MICROFONO`.
- **Solo en el bloque legible (datos extra):** modelo y numero de serie, tipo (notebook/escritorio), bateria, video, slots de RAM, espacio y salud de discos, IP/MAC, dominio o grupo de trabajo, activacion de Windows, fechas de instalacion y de BIOS, Office y antivirus.

Proyector, parlantes, mouse, teclado, UPS y microfono no se pueden detectar de forma confiable y quedan vacios en la fila.

## Cosas a tener en cuenta

- **Monitor:** solo cuenta el monitor **externo conectado** en ese momento. La pantalla integrada de una notebook no se incluye, asi que en una notebook sin monitor aparece "no detectado" y es correcto. Algunos adaptadores (VGA viejo, algunos KVM) impiden leer el modelo.
- **Impresora:** solo cuentan las impresoras **USB conectadas y encendidas** al momento de correr el script. Las de red, las virtuales (PDF, OneNote, Fax) y las instaladas hace tiempo que ya no estan enchufadas se ignoran. Si la impresora esta apagada, no aparece.
- **Camara y microfono:** la nota de microfono sale solo si la webcam tiene un dispositivo de audio propio en el mismo hardware. No depende del nombre.
- **Bateria:** Windows a veces no informa el estado de la bateria sin permisos de administrador. En ese caso la linea no aparece.
- **Sector y Observaciones:** los tabs que se escriban se eliminan automaticamente para no correr las columnas de la fila. Lo que se escribe en Observaciones se agrega despues de la nota automatica, separado con ` - `.
- **Archivos por PC:** cada PC tiene su propio `Inventario\`. `TODAS_LAS_FILAS.txt` no junta varias PCs: solo guarda la fila de la PC donde se corrio. Correrlo dos veces en la misma PC reemplaza su fila, no la duplica.
- **Nombre de la PC:** los archivos usan el nombre de la PC (`COMPUTERNAME`). Dos PCs con el mismo nombre se pisan entre si.
- **Ejecucion:** el `.bat` ya usa `-ExecutionPolicy Bypass`. Si se corre `inventario.ps1` directamente con PowerShell, puede fallar por la politica de ejecucion.

## Para quien modifique el script

- Mantener `inventario.ps1` **solo con caracteres ASCII** (sin tildes ni enies en comentarios o textos). Windows PowerShell 5.1 lee los archivos sin BOM como ANSI y los caracteres se rompen. Los caracteres de dibujo de la consola se arman con `[char]`.
- La fila tiene 21 columnas en un orden fijo que coincide con la planilla. Agregar informacion nueva va solo al bloque legible, nunca a nuevas columnas.
