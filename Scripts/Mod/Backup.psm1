using module ".\Util.psm1"

# Gestion de respaldos de archivos
class Backup {
    # Coleccion de archivos y directorios para respaldar
    [System.IO.FileSystemInfo[]]$Items

    # Estadisticas e informacion sobre los directorios procesados
    [hashtable]$DirStats

    Backup([System.IO.FileSystemInfo[]]$items) {
        $this.Items = $items
        $this.DirStats = @{}
    }

    # Crea una instancia desde un arreglo de rutas
    static [Backup] FromArray([string[]]$itemsPath) {
        $collected = @()

        # Revisar el arreglo
        foreach ($path in $itemsPath) {
            if (-not (Test-Path $path)) {
                throw "Ruta no encontrada: $path."
            }

            # Agregar el elemento
            $fsInfo = Get-Item -LiteralPath $path
            $collected += $fsInfo
        }

        return [Backup]::new($collected)
    }

    # Crea una instancia de la clase desde una ruta base
    static [Backup] FromPath([string]$path, [boolean]$includeEmpty) {
        if (-not (Test-Path $path)) {
            throw "Ruta no encontrada: $path."
        }

        $fsInfo = Get-Item -LiteralPath $path
        $totalItems = @()

        if ($fsInfo -is [System.IO.DirectoryInfo]) {
            # Obtener todos los elementos del directorio (recursivo o no, según tu necesidad)
            $totalItems = Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue

            # Si no se deben incluir directorios vacíos, filtrarlos
            if (-not $includeEmpty) {
                $totalItems = $totalItems | Where-Object {
                    -not ($_ -is [System.IO.DirectoryInfo] -and
                        -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue))
                }
            }

            # Si el directorio raíz está vacío y se pidió incluirlo
            if ($includeEmpty -and $totalItems.Count -eq 0) {
                $totalItems = @($fsInfo)
            }
        } else {
            $totalItems = @($fsInfo)
        }

        return [Backup]::new($totalItems)
    }

    # Excluye elementos a partir de patrones
    [Backup] Exclude([string[]]$patterns) {
        if (-not $patterns -or $patterns.Count -eq 0) {
            return $this
        }

        # Convertir los patrones en objetos WildcardPattern para coincidencias flexibles
        $wildcards = @()
        foreach ($p in $patterns) {
            if ($p -match '[\*\?]') {
                $wildcards += New-Object System.Management.Automation.WildcardPattern($p, 'IgnoreCase')
            } else {
                # Si no tiene comodines, considerarlo como regex o nombre literal
                $wildcards += $p
            }
        }

        # Filtrar los elementos
        $this.Items = $this.Items | Where-Object {
            $item = $_
            $name = $item.Name
            $path = $item.FullName

            # ¿Coincide con algun patron o esta dentro de una carpeta excluida?
            $isExcluded = $false
            foreach ($pat in $wildcards) {
                if ($pat -is [System.Management.Automation.WildcardPattern]) {
                    if ($pat.IsMatch($name) -or $pat.IsMatch($path)) {
                        $isExcluded = $true
                        break
                    }
                } else {
                    # Comparación por regex o nombre literal
                    if ($name -match "(?i)$pat" -or $path -match "(?i)$pat") {
                        $isExcluded = $true
                        break
                    }
                    # Si es una carpeta, eliminar también su contenido
                    if ($path -match "(?i)\\$pat(\\|$)") {
                        $isExcluded = $true
                        break
                    }
                }
            }
            -not $isExcluded
        }

        return $this
    }

    # Filtra elementos por su extensión
    [Backup] FilterExtensions([string[]]$fileExtensions) {
        if (-not $fileExtensions -or $fileExtensions.Count -eq 0) {
            return $this
        }

        # Normalizar las extensiones
        $normalizedExts = $fileExtensions | ForEach-Object {
            if ($_ -notmatch '^\.') { ".$_" } else { $_ }
        } | ForEach-Object { $_.ToLower() }

        # Filtrar elementos
        $this.Items = $this.Items | Where-Object {
            ($_ -is [System.IO.FileInfo]) -and
            ($_.Extension.ToLower() -in $normalizedExts)
        }

        return $this
    }

    # Calcula el tamano total en bytes de los elementos
    [int64] GetTotalSize() {
        # Si DirStats está vacío, se calcula con GetStats()
        $null = $this.GetStats()

        # Sumar todos los tamaños almacenados
        $total = 0
        foreach ($entry in $this.DirStats.Values) {
            $total += [int64]$entry.Size
        }

        return [int64]$total
    }

    [hashtable] GetStats() {
        if ($this.DirStats.Count -eq 0) {
            foreach ($item in $this.Items) {
                if ($item -is [System.IO.DirectoryInfo]) {
                    $files = Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
                    $size = ($files | Measure-Object Length -Sum).Sum
                    $this.DirStats[$item.Name] = @{
                        Size = [double]$size
                        Count = $files.Count
                    }
                } elseif ($item -is [System.IO.FileInfo]) {
                    $this.DirStats[$item.Name] = @{
                        Size = [double]$item.Length
                        Count = 1
                    }
                }
            }
        }
        return $this.DirStats
    }

    # Muestra un resumen de los elementos en el respaldo
    [int64] ShowSummary() {
        if (-not $this.Items -or $this.Items.Count -eq 0) {
            Write-Host "No hay elementos en el respaldo." -ForegroundColor DarkGray
            return 0
        }

        $null = $this.GetStats()

        $data = @()
        $totalBytes = 0

        foreach ($key in $this.DirStats.Keys) {
            $entry = $this.DirStats[$key]
            $totalBytes += $entry.Size
            $data += [PSCustomObject]@{
                Nombre = $key
                Archivos = $entry.Count
                Tamano = Format-Size $entry.Size
            }
        }

        Write-Host "Resumen del respaldo:" -ForegroundColor Cyan
        $data | Sort-Object Nombre | Format-Table -AutoSize | Out-Host
        Write-Host "Total aproximado: $(Format-Size $totalBytes)" -ForegroundColor Green

        return $totalBytes
    }

    # Copia los elementos a una ruta usando Robocopy
    [void] CopyTo([string]$destination) {
        # Crear directorio de destino si no existe
        if (-not (Test-Path $destination)) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
        }

        # 
        foreach ($item in $this.Items) {
            if ($item -is [System.IO.DirectoryInfo]) {
                $src  = $item.FullName
                $dest = Join-Path -Path $destination -ChildPath $item.Name

                Write-Host "[+] Copiando directorio: $src -> $dest" -ForegroundColor Cyan

                $roboArgs = @($src, $dest, '/E', '/R:3', '/W:0')
                & Robocopy.exe @roboArgs | Write-Host
                $rc = $LASTEXITCODE

                if ($rc -gt 1) {
                    Write-Warning "Robocopy finalizo con codigo $rc para '$src' -> '$dest'."
                }
            } elseif ($item -is [System.IO.FileInfo]) {
                $srcDir  = Split-Path -Path $item.FullName -Parent
                $destDir = $destination

                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }

                Write-Host "[+] Copiando archivo: $($item.FullName) -> $destDir" -ForegroundColor Yellow

                $roboArgs = @($srcDir, $destDir, $item.Name, '/R:3', '/W:0')
                & Robocopy.exe @roboArgs | Write-Host
                $rc = $LASTEXITCODE
                if ($rc -gt 1) {
                    Write-Warning "Robocopy finalizo con codigo $rc para '$($item.FullName)' -> '$destDir'."
                }
            } else {
                Write-Warning "Tipo de item no soportado: $item."
            }
        }
    }

    # Realiza una comparacion de tamanos con una ruta
    [void] CompareWith([string]$destination) {
        $origStats = $this.GetStats()
        $results = @()

        foreach ($dirName in $origStats.Keys) {
            $orig = $origStats[$dirName]
            $destPath = Join-Path $destination $dirName
            if (Test-Path $destPath) {
                $destFiles = Get-ChildItem -LiteralPath $destPath -Recurse -File -Force -ErrorAction SilentlyContinue
                $destSize = ($destFiles | Measure-Object Length -Sum).Sum
                $destCount = $destFiles.Count
            } else {
                $destSize = 0
                $destCount = 0
            }

            $fileComp = if ($orig.Count -eq $destCount) {
                "$($orig.Count) == $destCount"
            } else {
                "$($orig.Count) <> $destCount"
            }

            $results += [PSCustomObject]@{
                "Item" = $dirName
                "Tamano (O)" = Format-Size $orig.Size
                "Tamano (D)" = Format-Size $destSize
                "Archivos (O->D)" = $fileComp
            }
        }

        if ($results.Count -gt 0) {
            $results | Format-Table -AutoSize | Out-Host
        } else {
            Write-Warning "No se encontraron resultados para comparar."
        }
    }

    # Elimina directorios mas antiguos que una fecha dada usando Robocopy /MIR
    [void] Clean([datetime]$limitDate) {
        $remainingItems = @()
        foreach ($item in $this.Items) {
            if ($item -is [System.IO.DirectoryInfo]) {
                $dirDate = $item.LastWriteTime
                if ($dirDate -lt $limitDate) {
                    Write-Host "Eliminando: $($item.FullName) (ultima modificación: $dirDate)" -ForegroundColor Yellow

                    # Crear carpeta temporal vacía
                    $tempDir = Join-Path $env:TEMP ("rbk_empty_" + [guid]::NewGuid().ToString())
                    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

                    try {
                        # Vaciar contenido del directorio usando Robocopy /MIR
                        Write-Host "Vaciar con Robocopy..." -ForegroundColor DarkYellow
                        $roboArgs = @(
                            $tempDir,
                            $item.FullName,
                            '/MIR', '/E', '/R:3', '/W:0'
                        )

                        & Robocopy.exe @roboArgs | Out-Host
                        $rc = $LASTEXITCODE
                        if ($rc -gt 1) {
                            Write-Warning "Robocopy finalizo con $rc al vaciar '$($item.FullName)'."
                        } else {
                            Write-Host "Contenido borrado." -ForegroundColor Green
                        }

                        # Eliminar el directorio ya vacío
                        Write-Host "Eliminando directorio vacio..." -ForegroundColor DarkYellow
                        Remove-Item -LiteralPath $item.FullName -Force -Recurse -ErrorAction Stop
                        Write-Host "Directorio eliminado." -ForegroundColor Green

                        # Borrar carpeta temporal
                        Remove-Item -LiteralPath $tempDir -Force -Recurse -ErrorAction Stop

                        # Limpiar estadísticas
                        if ($this.DirStats.ContainsKey($item.Name)) {
                            $this.DirStats.Remove($item.Name)
                        }
                    }
                    catch {
                        Write-Warning "Error eliminando '$($item.FullName)': $_"

                        # Mantener el item si algo falla
                        $remainingItems += $item

                        # Intentar borrar tempDir si existe
                        if (Test-Path $tempDir) {
                            Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
                        }

                        continue
                    }
                } else {
                    # Si el directorio es reciente, conservarlo
                    $remainingItems += $item
                }
            }
            else {
                # Si no es directorio, no se borra
                $remainingItems += $item
            }
        }

        # Actualizar Items
        $this.Items = $remainingItems
    }
}

function Get-DriveFromPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $root = [System.IO.Path]::GetPathRoot((Resolve-Path $Path))
    $drive = Get-PSDrive | Where-Object { $_.Root -eq $root }
    if (-not $drive) {
        throw "No se pudo determinar la unidad de destino para '$Path'."
    }

    return $drive
}
