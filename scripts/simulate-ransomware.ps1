<#
.SYNOPSIS
  Simulador de ransomware para laboratorio de detección (SOC Lab).
  NO es malware: no se propaga, no persiste, no contacta ningún
  servidor externo y solo opera dentro de la carpeta indicada.

.DESCRIPCION
  1. Crea una carpeta de prueba con varios archivos "señuelo".
  2. "Cifra" cada archivo con un XOR simple y clave fija (reversible,
     solo para generar el patrón de comportamiento, no seguridad real).
  3. Renombra cada archivo cifrado añadiendo la extensión .locked.
  4. Elimina el archivo original sin cifrar.
  5. Deja una nota de rescate, como hacen las familias de ransomware
     reales, para que el patrón sea reconocible en los logs y en
     disco.

.USO
  Ejecutar en PowerShell, en el Windows 11 del laboratorio:
    .\simulate-ransomware.ps1

  Para revertir y limpiar la carpeta de prueba:
    .\simulate-ransomware.ps1 -Cleanup

.ESTRUCTURA DEL SCRIPT
  New-TestFiles     -> prepara los archivos señuelo.
  Protect-FileXor   -> "cifra" un archivo (XOR + .locked + borrado del original).
  Start-Simulation  -> orquesta el ataque completo (flujo principal).
  Remove-Simulation -> limpieza: borra la carpeta de prueba entera.

.LO QUE VE EL SOC (relación con la detección)
  - Creación masiva de archivos *.locked en pocos segundos (Sysmon Event ID 11,
    FileCreate -> ver configs/sysmon/sysmon-filecreate-ransomware.xml).
  - Creación de README_RECOVER.txt (nota de rescate).
  - Estos eventos los recoge el agente de Wazuh y los evalúan las reglas de
    detections/local_rules.xml.
#>

# ---------------------------------------------------------------------------
# PARÁMETROS
# ---------------------------------------------------------------------------
param(
    # Carpeta donde se crean y "cifran" los archivos de prueba.
    # Por defecto: Documentos del usuario actual\LabRansomwareTest.
    # Es la ÚNICA ruta que el script toca (tanto al atacar como al limpiar).
    [string]$TargetFolder = "$env:USERPROFILE\Documents\LabRansomwareTest",

    # Si se indica (-Cleanup), no ataca: borra la carpeta de prueba y termina.
    [switch]$Cleanup
)

# ---------------------------------------------------------------------------
# CONSTANTES
# ---------------------------------------------------------------------------
# Extensión que se añade a cada archivo "cifrado" (patrón típico de ransomware;
# es lo que busca la regla de detección).
$ExtensionLocked = ".locked"

# Nombre de la nota de rescate que se deja en la carpeta.
$RansomNote = "README_RECOVER.txt"

# ---------------------------------------------------------------------------
# New-TestFiles
# Prepara el escenario: crea la carpeta objetivo (si no existe) y genera
# 8 archivos .txt señuelo con contenido de prueba y la fecha actual.
# Sin parámetros: usa $TargetFolder del ámbito del script.
# ---------------------------------------------------------------------------
function New-TestFiles {
    # Crea la carpeta objetivo solo si todavía no existe.
    if (-not (Test-Path $TargetFolder)) {
        New-Item -ItemType Directory -Path $TargetFolder | Out-Null
    }

    # Genera documento_prueba_1.txt ... documento_prueba_8.txt
    1..8 | ForEach-Object {
        $path = Join-Path $TargetFolder "documento_prueba_$_.txt"
        "Contenido de prueba del archivo $_ - $(Get-Date)" | Out-File -FilePath $path -Encoding UTF8
    }
    Write-Host "[+] Creados 8 archivos de prueba en $TargetFolder"
}

# ---------------------------------------------------------------------------
# Protect-FileXor
# "Cifra" UN archivo imitando el comportamiento de un ransomware:
#   1) lee todos sus bytes,
#   2) aplica XOR con una clave fija de 1 byte ('K'),
#   3) escribe el resultado en un archivo nuevo con extensión .locked
#      (esta creación es lo que genera el evento Sysmon de FileCreate),
#   4) borra el archivo original.
# NO es cifrado real: XOR con clave fija es trivialmente reversible
# (volver a aplicar XOR con 'K' recupera el contenido).
#
# Parámetro:
#   -Path    Ruta completa del archivo a "cifrar".
# Devuelve:
#   La ruta del nuevo archivo .locked.
# ---------------------------------------------------------------------------
function Protect-FileXor {
    param([string]$Path)

    # Lee el contenido completo del archivo como array de bytes.
    $bytes = [System.IO.File]::ReadAllBytes($Path)

    # Clave XOR: el código del carácter 'K' convertido a byte.
    $key = [byte][char]'K'

    # Recorre cada byte y lo "cifra" con XOR (-bxor = XOR a nivel de bits).
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = $bytes[$i] -bxor $key
    }

    # Escribe el contenido "cifrado" en un archivo nuevo: original + ".locked".
    $newPath = "$Path$ExtensionLocked"
    [System.IO.File]::WriteAllBytes($newPath, $bytes)

    # Elimina el original en claro, como haría un ransomware real.
    Remove-Item -Path $Path -Force

    # Devuelve la ruta nueva para que quien llama pueda mostrarla.
    return $newPath
}

# ---------------------------------------------------------------------------
# Start-Simulation
# Flujo principal del ataque simulado:
#   1) crea los archivos señuelo (New-TestFiles),
#   2) cifra uno a uno todos los documento_prueba_*.txt (Protect-FileXor),
#   3) deja la nota de rescate en la carpeta.
# Sin parámetros.
# ---------------------------------------------------------------------------
function Start-Simulation {
    New-TestFiles

    Write-Host "[+] Iniciando cifrado simulado..."

    # Lista solo los .txt señuelo (el filtro evita tocar cualquier otro archivo).
    $files = Get-ChildItem -Path $TargetFolder -Filter "documento_prueba_*.txt"
    foreach ($f in $files) {
        $locked = Protect-FileXor -Path $f.FullName
        Write-Host "    Cifrado: $($f.Name) -> $(Split-Path $locked -Leaf)"
        Start-Sleep -Milliseconds 300   # ritmo de "cifrado masivo" visible en los logs
    }

    # Texto de la nota de rescate (here-string). Deja claro que es un ejercicio
    # de laboratorio y cómo revertirlo.
    $noteText = @"
TUS ARCHIVOS HAN SIDO CIFRADOS (SIMULACION DE LABORATORIO)

Este es un ejercicio controlado de laboratorio SOC.
No se ha cifrado ningun archivo real del sistema.
Para revertir, ejecuta: simulate-ransomware.ps1 -Cleanup
"@
    # Guarda la nota en la carpeta objetivo.
    $noteText | Out-File -FilePath (Join-Path $TargetFolder $RansomNote) -Encoding UTF8

    Write-Host "[+] Nota de rescate creada: $RansomNote"
    Write-Host "[+] Simulacion completada en: $TargetFolder"
}

# ---------------------------------------------------------------------------
# Remove-Simulation
# Limpieza / reversión: elimina por completo la carpeta de prueba
# (archivos .locked y nota incluidos). Si no existe, solo avisa.
# Sin parámetros.
# ---------------------------------------------------------------------------
function Remove-Simulation {
    if (Test-Path $TargetFolder) {
        Remove-Item -Path $TargetFolder -Recurse -Force
        Write-Host "[+] Carpeta de prueba eliminada: $TargetFolder"
    } else {
        Write-Host "[!] No existe la carpeta de prueba, nada que limpiar."
    }
}

# ---------------------------------------------------------------------------
# PUNTO DE ENTRADA
# Con -Cleanup limpia; sin él, lanza la simulación.
# ---------------------------------------------------------------------------
if ($Cleanup) {
    Remove-Simulation
} else {
    Start-Simulation
}