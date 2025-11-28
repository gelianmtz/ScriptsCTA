using module ".\Mod\Backup.psm1"
using module ".\Mod\Console.psm1"

param(
    [Alias("o")]
    [string]$Origen,

    [Alias("d")]
    [string]$Destino,

    [Alias("e")]
    [string]$Excluir,

    [Alias("n")]
    [switch]$SinConfirmar
)

try {
    # Leer la ruta de origen y destino del respaldo
    if (-not $Origen) {
        $Origen = Read-Input -Prompt "Ruta de origen" -Default "C:\Users\$env:USERNAME"
    }
    if (-not $Destino) {
        $Destino = Read-Input -Prompt "Ruta de destino"
    }

    # Crear el respaldo base
    $backup = [Backup]::FromPath($Origen, $false)

    # Aplicar exclusiones
    if ($Excluir -and $Excluir.Count -gt 0) {
        $backup = $backup.Exclude($Excluir)
    }

    # Verificar y confirmar respaldo
    if (-not $SinConfirmar) {
        # Mostrar resumen de los archivos para respaldar
        $backupSize = $backup.ShowSummary()

        # Obtener unidad de destino y calcular espacio
        $destDrive = Get-DriveFromPath $Destino
        $freeBytes = $destDrive.Free
        $remainingBytes = $freeBytes - $backupSize
        Write-Host "Espacio disponible en $($destDrive.Name): $(Format-Size $freeBytes)" -ForegroundColor Cyan
        if ($remainingBytes -lt 0) {
            throw "No hay suficiente espacio en $($destDrive.Name)."
        } else {
            Write-Host "Quedaran $(Format-Size $remainingBytes) libres tras el respaldo." -ForegroundColor Yellow
        }

        # Esperar confirmación del usuario
        Confirm-Operation "Confirmar respaldo?"
    }

    # Ejecutar el respaldo
    $backup.CopyTo($Destino)

    # Comprobar archivos y pesos
    $backup.CompareWith($Destino)
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    Exit-Program
}
