using module ".\Mod\Console.psm1"
using module ".\Mod\Util.psm1"

try {
    # Obtener el adaptador activo con IPv4
    $adapter = Get-NetIPConfiguration | Where-Object {
        $_.IPv4Address -ne $null -and $_.NetAdapter.Status -eq "Up" -and $_.IPv4DefaultGateway -ne $null
    } | Select-Object -First 1
    if (-not $adapter) {
        throw "No se encontro ningun adaptador de red activo."
    }

    # Crear objeto de configuracion
    $config = [IPConfiguration]::FromAdapter($adapter)

    # Guardar archivo
    $mac = $config.MACAddress -replace "[:\-]", ""
    $filename = "IP-$mac.json"
    $rootDir = Split-Path -Qualifier $MyInvocation.MyCommand.Definition
    $outputDir = Join-Path $rootDir "IP"
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory | Out-Null
    }
    $outputPath = Join-Path $outputDir $filename
    $config.ToJson() | Out-File -FilePath $outputPath -Encoding UTF8 -Force

    # Finalizar
    Write-Host $config.ToString()
    Write-Host "Configuracion de red guardada en $outputPath."
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    Exit-Program
}
