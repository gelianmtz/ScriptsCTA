# Informacion de la computadora
class ComputerInfo {
    [string]$ComputerName
    [string]$Manufacturer
    [string]$Model
    [string]$WinEdition
    [string]$WinVersion
    [int]$BuildNumber

    ComputerInfo() {
        $this.ComputerName = $env:COMPUTERNAME
        $cs = Get-CimInstance Win32_ComputerSystem
        $os = Get-CimInstance Win32_OperatingSystem

        $this.Manufacturer = ($cs.Manufacturer).Trim() -replace '[\\/:\*\?"<>|]', '_'
        $this.Model = ($cs.Model).Trim() -replace '[\\/:\*\?"<>|]', '_'

        $editionRaw = $os.Caption.Trim()
        $build = $os.BuildNumber
        $this.BuildNumber = $build

        $this.WinEdition = if ($build -ge 22000) {
            "Windows 11 $($editionRaw -replace '.*(Home|Pro|Enterprise|Education).*', '$1')"
        } else {
            "Windows 10 $($editionRaw -replace '.*(Home|Pro|Enterprise|Education).*', '$1')"
        }

        try {
            $releaseId = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop).DisplayVersion
            if (-not $releaseId) {
                $releaseId = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop).ReleaseId
            }
        } catch {
            $releaseId = "Desconocida"
        }
        $this.WinVersion = $releaseId -replace '[\\/:\*\?"<>|]', '_'
    }
}

function Format-Size {
    [OutputType([string])]
    param([double]$Bytes)

    switch ($Bytes) {
        {$_ -ge 1TB} { "{0:N2} TB" -f ($Bytes / 1TB); break }
        {$_ -ge 1GB} { "{0:N2} GB" -f ($Bytes / 1GB); break }
        {$_ -ge 1MB} { "{0:N2} MB" -f ($Bytes / 1MB); break }
        {$_ -ge 1KB} { "{0:N2} KB" -f ($Bytes / 1KB); break }
        default { "{0:N0} B" -f $Bytes }
    }

    <#
        .SYNOPSIS
        Converts a byte value into a human-readable file size format.

        .DESCRIPTION
        The Format-Size function takes a numeric value representing bytes and converts it 
        into a more readable size string using appropriate units (KB, MB, GB, TB). 
        The result is formatted to two decimal places for clarity.

        .PARAMETER Bytes
        Specifies the size in bytes to be converted. This parameter accepts a numeric (double) value.

        .OUTPUTS
        System.String
        The function returns a formatted string that represents the size in the most appropriate unit.

        .EXAMPLE
        Format-Size -Bytes 1048576
        Returns: "1.00 MB"
    #>
}

function Import-Env {
    [OutputType([hashtable])]
    param([string]$Path)

    $config = @{}
    foreach ($line in Get-Content $Path) {
        if ($line -match "^\s*#" -or $line.Trim() -eq "") {
            continue
        }
        $parts = $line -split '=', 2
        $config[$parts[0]] = $parts[1]
    }
    return $config

    <#
        .SYNOPSIS
        Loads key=value pairs from a .env-style file into a hashtable.

        .DESCRIPTION
        Import-Env reads a file containing environment-style variable definitions in:
            VAR=value
        format and returns them in a PowerShell hashtable.  
        Empty lines and comments beginning with "#" are ignored.

        .PARAMETER Path
        The full path to the .env or config file.

        .OUTPUTS
        Hashtable
        A hashtable with keys and values extracted from the file.

        .EXAMPLE
        $config = Import-Env -Path ".\.env"
        $config["TOKEN"]

        .NOTES
        The function supports lines with '=' only in the first pair.
    #>
}
