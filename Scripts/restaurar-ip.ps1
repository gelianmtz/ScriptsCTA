using module ".\Mod\Console.psm1"
using module ".\Mod\Util.psm1"

try {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Ejecuta el script como administrador."
    }

    # Obtener el adaptador activo
    $adapter = Get-NetIPConfiguration | Where-Object {
        $_.IPv4Address -ne $null -and $_.NetAdapter.Status -eq "Up"
    } | Select-Object -First 1
    if (-not $adapter) {
        throw "No se encontro ningun adaptador de red activo."
    }

    # Calcular nombre del archivo segun la MAC
    $mac = $adapter.NetAdapter.MacAddress -replace "[:\-]", ""
    $filename = "IP-$mac.json"
    $rootDir = Split-Path -Qualifier $MyInvocation.MyCommand.Definition
    $outputDir = Join-Path $rootDir "IP"
    $inputPath = Join-Path $outputDir $filename

    # Verificar existencia del archivo
    if (-not (Test-Path $inputPath)) {
        throw "No se encontro el archivo de configuracion '$inputPath'."
    }

    # Leer la configuracion desde el JSON
    Write-Host "Restaurando configuracion desde $inputPath..."
    $json = Get-Content -Path $inputPath -Raw
    $config = [IPConfiguration]::FromJson($json)
    Write-Host "Configuracion detectada:"
    Write-Host $config.ToString()

    # Aplicar configuración
    Write-Host "Aplicando configuracion en $($config.InterfaceAlias)..."
    $config.Apply()

    # Finalizar
    Write-Host "Configuracion aplicada correctamente."
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    Exit-Program
}

