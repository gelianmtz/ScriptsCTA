using module ".\Mod\Console.psm1"
using module ".\Mod\Network.psm1"

# Probar conexion a la NAS
try {
    $ip = [NAS]::IP
    if ($PSScriptRoot -like "$ip*") {
        Write-Host "Conectado a la NAS."
        $base = "\\$ip\SMB\Drivers"
    } else {
        $nas = [NAS]::ConnectTo("SMB\Drivers")
        $base = "$($nas.Name):"
    }

    Get-ChildItem $base | Write-Host
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    [NAS]::Disconnect()

    Exit-Program
}
