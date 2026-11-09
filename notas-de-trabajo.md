# Cuaderno de Intervención - CASO-01 (FORENSIC_10)
**Investigador:** Alejandro Álvarez Romero
**Fecha de actuación:** 27, 28 y 30 de octubre de 2026 & 03/11/2026
**Escenario:** Máquina Virtual FORENSIC_10 (Entorno Legacy - Windows 7 Professional)

---

## PARTE 1: ADQUISICIÓN EN VIVO

Dia 27/10/2026

* **[20:22] - Preparación y Estado Inicial de la Escena:**
  * Se inicia la actuación sobre la máquina virtual encendida. La sesión se encontraba bloqueada y se accede mediante la contraseña facilitada por el administrador.
  * **Comprobación de hora:** Se comprueba la hora del sistema frente a la del equipo físico anfitrión (UTC/CET). No se aprecia desfase significativo. Se realiza captura de pantalla inicial.
  * **Marca Forense:** Para garantizar la trazabilidad del proceso y comprobar el comportamiento de la volatilidad, genero dos marcas forenses (ficheros .txt). Una se guarda en el Escritorio y la otra se deja en ejecución abierta en la memoria RAM mediante el proceso `notepad.exe`.

* **[21:26] - Adquisición de la Memoria RAM:**
  * **Incidencia:** Se intentó utilizar la herramienta **DumpIt**. Sin embargo, arrojó un error de firma digital (0xC0000428) debido a incompatibilidades con el entorno legacy (Windows 7).
  * **Solución y Herramienta utilizada:** Se decide utilizar **WinPmem** (`winpmem_mini_x64_rc2.exe`) por su alta compatibilidad con sistemas antiguos.
  * **Acción:** Se ejecuta la herramienta obteniendo el fichero `volcado_ram.raw`. 
  * **Verificación:** Se calcula el hash SHA-256 del fichero generado para garantizar su integridad desde el primer momento.

* **[21:47] - Recolección de Datos Volátiles:**
  * **Incidencia:** El script original `respuesta-en-vivo.ps1` falló al ejecutarse, ya que el sistema objetivo cuenta con PowerShell 2.0 (versión obsoleta) y carece de módulos modernos.
  * **Solución y Herramienta utilizada:** Se procedió a reescribir y adaptar el script para entornos Legacy, utilizando llamadas directas a WMI (Windows Management Instrumentation) compatibles con PS 2.0.
  * **Acción:** La ejecución generó con éxito el directorio `CASO-01_FORENSIC10_20261027-204647` conteniendo los registros (conexiones, procesos, usuarios) en formato CSV y el archivo `hashes_archivos.csv` con sus respectivas firmas SHA-256.

* **[22:40] - Captura de Tráfico de Red:**
  * **Herramienta utilizada:** Sniffer nativo del hipervisor (VBoxManage) ejecutado desde la máquina física (anfitrión).
  * **Justificación:** Se realiza "desde fuera" (modo TAP) para cumplir con el principio de mínima alteración de la evidencia, evitando instalar herramientas como Wireshark o WinPcap dentro del sistema comprometido.
  * **Acción:** Se inicia la captura mediante el comando:
    `VBoxManage controlvm "FORENSIC_10" nictracefile1 E:\trafico_red\captura_red.pcap` seguido de `nictrace1 on`.
  * Tras un periodo de captura de aproximadamente 3 minutos, se detiene con `nictrace1 off`. Se calcula el hash SHA-256 del archivo resultante.

Dia 28/10/2026

* **[19:40] - Triaje de Artefactos de Disco:**
  * **Incidencia:** Las herramientas modernas KAPE y la versión estándar de Velociraptor fallaron por dependencias de librerías (.NET) no presentes en el Windows 7.
  * **Solución y Herramienta utilizada:** Se preparó un recolector offline de **Velociraptor** empaquetado en el equipo anfitrión y se ejecutó en la evidencia.
  * **Acción:** Se extrajo con éxito el archivo contenedor `.zip` (`Triage-FORENSE-06...`) que incluye artefactos críticos como la `$MFT` en la ruta `uploads/ntfs/`. Se calcula su hash de integridad.

* **[19:59] - Comprobación de Cifrado de Volúmenes:**
  * **Comando ejecutado:** `manage-bde -status` (ejecutado desde CMD con privilegios).
  * **Resultado:** El sistema reporta que la protección está desactivada y los volúmenes se encuentran "Totalmente descifrados".
  * **Decisión técnica:** Al confirmar que no existe cifrado BitLocker activo, no es necesario extraer claves de recuperación de la RAM ni mantener la máquina encendida para volcar el disco en vivo. Se puede proceder a un apagado para la adquisición post-mortem.

* **[20:14] - Apagado del Sistema (Técnica empleada):**
  * **Decisión:** Se procede a realizar un **apagado abrupto** ("Pull the plug") forzando la detención de la máquina desde el menú de VirtualBox.
  * **Justificación forense:** Si se hubiera realizado un apagado ordenado (Inicio > Apagar), el sistema operativo habría activado la caché de escritura diferida de NTFS (Lazy Writer), volcando datos temporales de la RAM al disco duro. Esto alteraría las fechas (MACB) de la `$MFT`, destruiría evidencia en la memoria volátil y borraría archivos temporales. 
  * **Comprobación del resultado:** Se corrobora posteriormente que la marca forense en ejecución (Notepad) quedó retenida en la RAM (`volcado_ram.raw` analizado con HxD) y no llegó a registrarse en el disco, confirmando que la técnica de apagado preservó la escena con éxito.


  
## PARTE 2: ADQUISICIÓN POST-MORTEM (Disco y Pendrive)

DIA 03/11/2026

* **[10:00] - Preservación de Hashes Iniciales de la VM (Antes de crear la imagen):**
  * Para garantizar el Principio de Locard y demostrar la inalterabilidad de la evidencia original durante la copia, calculamos el hash SHA-256 de los ficheros de la máquina virtual (apagada) antes de proceder a la creación de la imagen E01:
    * `FORENSIC_10_disk0.vdi = 3BF8F69725C790DE0F76CD713EB2454A8F63DE3FC9D2DC17015C9EFE236C4436`
    * `FORENSIC_10.vbox = 8D421F9731B66E5A761B6BD05790D5C0BBDB9D5D6DE61DD500B31BE43C7C0BCB`
    * `VBox.log = 8DD67718FA94DEA0F5C65D8F00A314D2A62A79871F20D247A0685FDD37C0EB75`

* **[10:07] - Creación de Imagen E01 del Disco Principal:**
  * Seguimos el procedimiento normal de adquisición con FTK Imager. Seleccionamos el origen como "Image File" y cargamos el archivo `FORENSIC_10_disk0.vdi`.
  * Se marca la opción para verificar la imagen después de ser creada ("Verify images after they are created"). 
  * Tras finalizar la creación de la imagen, **volvemos a calcular el hash** del archivo `FORENSIC_10_disk0.vdi` original mediante PowerShell.
  * **Resultado:** Vemos que el hash SHA-256 sigue siendo exactamente igual al calculado inicialmente (`3BF8F697...`), demostrando que el proceso de adquisición no ha modificado los datos originales.

* **[19:45] - Preparación y Bloqueo del Pendrive USB:**
  * **Incidencia:** Para ejecutar el script de bloqueo, Windows bloqueó el proceso por seguridad. Tuvimos que usar el comando `Set-ExecutionPolicy Bypass -Scope Process -Force` en PowerShell para permitir la ejecución de scripts.
  * **Bloqueo:** Ejecutamos `.\bloqueo-usb.ps1` **aún sin conectar el pendrive**. Cuando se abrió el menú del script en PowerShell, le dimos a la opción "Activar todos" (WriteProtect). 
  * Una vez configurado el registro, **conectamos el pendrive**. A partir de ese momento, la escritura quedó bloqueada físicamente. Se comprobó su estado y se capturó la pantalla.

* **[20:06] - Creación de Imagen E01 del Pendrive:**
  * Abrimos FTK Imager, seleccionamos `File > Create Disk Image` y marcamos **Physical Drive**, buscando nuestro pendrive USB en la lista de dispositivos.
  * Agregamos el destino de la imagen, formato **E01** (el que estamos usando por defecto), y rellenamos los metadatos de la evidencia.
  * Seleccionamos la carpeta de destino, nombramos el archivo, aplicamos la encriptación requerida, y marcamos la verificación final.

  ## PARTE 3: ANÁLISIS DE VOLATILIDAD (Comprobación de las Marcas)

Dia 30/10/2026

* **[13:30] - Metodología de búsqueda de Marcas Forenses con HxD:**
  * El objetivo de esta fase fue comprobar el comportamiento del sistema ante el apagado abrupto (Pull the plug) mediante la localización de las dos marcas de texto creadas en la Parte 1.
  * **Búsqueda en la Memoria Volátil (RAM):**
    * Se abrió el archivo `volcado_ram.raw` utilizando el editor hexadecimal **HxD**.
    * Se realizó una búsqueda de cadenas de texto (Ctrl+F) configurando la codificación obligatoriamente en **UTF-16 LE (Unicode)**, ya que es el formato que utiliza Windows para procesar texto en memoria de manera nativa.
    * **Resultado:** La marca dejada en ejecución (sin guardar en el bloc de notas) fue localizada exitosamente en la memoria volátil.
  * **Búsqueda en el Sistema de Ficheros (Disco):**
    * Posteriormente, se abrió el archivo `$MFT` (Tabla Maestra de Archivos), el cual fue extraído previamente durante la fase de triaje.
    * Mediante HxD, se realizó una nueva búsqueda de texto para localizar el nombre exacto del archivo `.txt` que habíamos guardado en el Escritorio de la máquina virtual.
    * **Resultado:** El archivo guardado en el Escritorio sí fue localizado en los registros de la `$MFT`. Sin embargo, no hubo rastro en el disco de la marca que dejamos abierta en la RAM.
  * **Conclusión Forense:** Este hallazgo cruzado justifica metodológicamente el orden de volatilidad empleado. El apagado abrupto cortó la corriente antes de que el proceso de "escritura diferida" (Lazy Writer) de Windows pudiera volcar los datos temporales del Bloc de Notas al disco duro.

  ## PARTE 4: CADENA DE CUSTODIA Y ENTREGA

Dia 03/11/2026

* **[20:30] - Copias de Trabajo (Imagen Maestra vs Imagen de Trabajo):**
  * Para garantizar la preservación de la evidencia original, se procede a realizar una copia (copia de trabajo) de los archivos `.E01` (tanto del disco como del pendrive).
  * Se verifica mediante cálculo hash que las copias de trabajo mantienen idéntica firma que las imágenes maestras.

* **[20:48] - Archivo Global de Hashes (Consolidación):**
  * Para la entrega del repositorio al tribunal/compañero, se genera un archivo que contenga todos los hashes de todas las evidencias.
  * Desde un terminal de Linux, en la raíz del repositorio, se ejecuta: 
    `find . -type f ! -name hashes.sha256 -exec sha256sum {} + > hashes.sha256`
Dia 09/11/2026

* **[10:30] - Verificación Cruzada y Registro de Custodia:**
  * Se realiza la entrega física del repositorio de evidencias al compañero Hugo Pérez.
  * El compañero ejecuta el comando `sha256sum -c hashes.sha256` en el terminal para que el sistema valide si todos los archivos mantienen la integridad original. El sistema devuelve "La suma coincide / OK".
  * Se procede a firmar la entrega y devolución en la plantilla del acta correspondiente (`registro-custodia.pdf`).
