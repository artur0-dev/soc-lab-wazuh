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
#>

param(
    [string]$TargetFolder = "$env:USERPROFILE\Documents\LabRansomwareTest",
    [switch]$Cleanup
)

$ExtensionLocked = ".locked"
$RansomNote = "README_RECOVER.txt"

function New-TestFiles {
    if (-not (Test-Path $TargetFolder)) {
        New-Item -ItemType Directory -Path $TargetFolder | Out-Null
    }
    1..8 | ForEach-Object {
        $path = Join-Path $TargetFolder "documento_prueba_$_.txt"
        "Contenido de prueba del archivo $_ - $(Get-Date)" | Out-File -FilePath $path -Encoding UTF8
    }
    Write-Host "[+] Creados 8 archivos de prueba en $TargetFolder"
}

function Protect-FileXor {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $key = [byte][char]'K'
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = $bytes[$i] -bxor $key
    }
    $newPath = "$Path$ExtensionLocked"
    [System.IO.File]::WriteAllBytes($newPath, $bytes)
    Remove-Item -Path $Path -Force
    return $newPath
}

function Start-Simulation {
    New-TestFiles

    Write-Host "[+] Iniciando cifrado simulado..."
    $files = Get-ChildItem -Path $TargetFolder -Filter "documento_prueba_*.txt"
    foreach ($f in $files) {
        $locked = Protect-FileXor -Path $f.FullName
        Write-Host "    Cifrado: $($f.Name) -> $(Split-Path $locked -Leaf)"
        Start-Sleep -Milliseconds 300   # ritmo de "cifrado masivo" visible en los logs
    }

    $noteText = @"
TUS ARCHIVOS HAN SIDO CIFRADOS (SIMULACION DE LABORATORIO)

Este es un ejercicio controlado de laboratorio SOC.
No se ha cifrado ningun archivo real del sistema.
Para revertir, ejecuta: simulate-ransomware.ps1 -Cleanup
"@
    $noteText | Out-File -FilePath (Join-Path $TargetFolder $RansomNote) -Encoding UTF8

    Write-Host "[+] Nota de rescate creada: $RansomNote"
    Write-Host "[+] Simulacion completada en: $TargetFolder"
}

function Remove-Simulation {
    if (Test-Path $TargetFolder) {
        Remove-Item -Path $TargetFolder -Recurse -Force
        Write-Host "[+] Carpeta de prueba eliminada: $TargetFolder"
    } else {
        Write-Host "[!] No existe la carpeta de prueba, nada que limpiar."
    }
}

if ($Cleanup) {
    Remove-Simulation
} else {
    Start-Simulation
}
