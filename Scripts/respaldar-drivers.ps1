using module ".\Mod\Network.psm1"
using module ".\Mod\Util.psm1"
using module ".\Mod\Console.psm1"

try {
    # Crear objeto con la informacion del sistema
    $info = [ComputerInfo]::new()

    # Crear carpeta temporal
    $tempDest = Join-Path $env:TEMP "$($info.Manufacturer)\$($info.Model)\$($info.WinEdition)\$($info.WinVersion)"
    if (Test-Path $tempDest) {
        Remove-Item -Path $tempDest -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDest -Force | Out-Null

    # Exportar drivers localmente
    Write-Host "Iniciando respaldo de drivers localmente...`n"
    try {
        pnputil /export-driver * "$tempDest"
        Write-Host "Drivers exportados localmente en $tempDest."
    } catch {
        throw "Ocurrio un error al exportar los drivers."
    }

    # Conectarse a la NAS
    $ip = [NAS]::IP
    $driveName = [NAS]::DriveName
    if ($PSScriptRoot -like "$ip*") {
        Write-Host "Conectado a la NAS."
        $destinationBase = "\\$ip\SMB\Drivers"
    } else {
        [NAS]::ConnectTo("SMB\Drivers") | Out-Null
        $destinationBase = "$($driveName):"
    }

    # Crear ruta de destino completa
    $destinationPath = "$destinationBase\$($info.Manufacturer)\$($info.Model)\$($info.WinEdition)\$($info.WinVersion)"
    $destinationPath = $destinationPath -replace '\\{3,}', '\\'

    # Limpiar respaldo previo
    if (Test-Path $destinationPath) {
        Write-Warning "Eliminando respaldo previo en $destinationPath..."
        Remove-Item -Path $destinationPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

    # Copiar drivers
    Write-Host "Copiando drivers al servidor..."
    Copy-Item -Path "$tempDest\*" -Destination $destinationPath -Recurse -Force

    # Finalizar
    Write-Host "Drivers respaldados correctamente en $destinationPath."
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    # Limpiar carpeta temporal
    $tempPath = Join-Path $env:TEMP "$($info.Manufacturer)"
    if (Test-Path $tempPath) {
        Remove-Item -Path $tempPath -Recurse -Force
        Write-Warning "Directorio temporal eliminado."
    }

    # Desmontar la NAS
    [NAS]::Disconnect()

    Exit-Program
}
