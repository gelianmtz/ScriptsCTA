using module ".\Mod\Console.psm1"
using module ".\Mod\Network.psm1"
using module ".\Mod\Util.psm1"

try {
    # Crear objeto con la informacion del sistema
    $info = [ComputerInfo]::new()

    # Conectarse a la NAS
    $ip = [NAS]::IP
    $driveName = [NAS]::DriveName
    if ($PSScriptRoot -like "$ip*") {
        Write-Host "Conectado a la NAS."
        $sourceBase = "\\$ip\SMB\Drivers"
    } else {
        [NAS]::ConnectTo("SMB\Drivers") | Out-Null
        $sourceBase = "$($driveName):"
    }

    # Crear ruta de origen donde estan los drivers
    $sourcePath = "$sourceBase\$($info.Manufacturer)\$($info.Model)\$($info.WinEdition)\$($info.WinVersion)"
    $sourcePath = $sourcePath -replace '\\{3,}', '\\'
    if (-not (Test-Path $sourcePath)) {
        throw "No se encontraron drivers en $sourcePath."
    }

    # Instalar todos los drivers .inf desde el origen
    Write-Host "Iniciando restauracion de drivers..."
    Get-ChildItem -Path $sourcePath -Recurse -Include *.inf | ForEach-Object {
        $driverPath = $_.FullName
        Write-Host "Instalando driver: $driverPath"
        try {
            pnputil /add-driver "$driverPath" /install
        } catch {
            Write-Warning "Error al instalar $driverPath."
        }
    }

    # Finalizar
    Write-Host "Proceso de restauracion completado."
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    # Desmontar la NAS
    [NAS]::Disconnect()

    Exit-Program
}
