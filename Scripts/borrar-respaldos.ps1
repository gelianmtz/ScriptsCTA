using module ".\Mod\Backup.psm1"
using module ".\Mod\Console.psm1"

param(
    [Alias("d")]
    [string]$Directorio,

    [Alias("f")]
    [datetime]$FechaLimite,

    [Alias("s")]
    [switch]$SoloRespaldo
)

try {
    # Validar que el directorio existe
    if (-not (Test-Path -LiteralPath $Directorio)) {
        throw "El directorio especificado no existe: $Directorio"
    }

    Write-Host "Directorio recibido: $Directorio" -ForegroundColor Cyan
    Write-Host "Fecha limite: $FechaLimite" -ForegroundColor Cyan

    $backup = [Backup]::FromPath($Directorio, $true)

    if ($SoloRespaldo) {
        # Solo directorios cuyo nombre contenga 'respaldo'
        $backup.Items = $backup.Items | Where-Object {
            $_ -is [System.IO.DirectoryInfo] -and $_.Name -match '(?i)respaldo'
        }

        if ($backup.Items.Count -eq 0) {
            Write-Warning "No se encontraron directorios de respaldo."
        }
    }

    # Ejecutar limpieza
    $backup.Clean($FechaLimite)

    Write-Host "Eliminacion completada correctamente." -ForegroundColor Green
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    Exit-Program
}
