using module ".\Util.psm1"

# Conexion a la NAS
class NAS {
    static [string]$DriveName
    static [string]$IP
    static [string]$User
    static [string]$Password

    static NAS() {
        try {
            $envPath = Join-Path $PSScriptRoot "..\..\nas.env"

            # Normalizar la ruta si existe
            if (Test-Path $envPath) {
                $envPath = (Resolve-Path $envPath).Path
            } else {
                throw "Archivo de configuracion no encontrado: $envPath"
            }

            $config = Import-Env $envPath

            [NAS]::DriveName = $config["DRIVE_NAME"]
            [NAS]::IP = "\\" + $config["IP"]
            [NAS]::User = $config["USER"]
            [NAS]::Password = $config["PASSWORD"]

            Write-Host "Configuracion de la NAS cargada correctamente."

        } catch {
            Write-Error $_.Exception.Message
            throw
        }
    }

    # Se conecta a la NAS y la monta como una unidad de PowerShell
    static [System.Management.Automation.PSDriveInfo] ConnectTo([string]$path) {
        $nasDriveName = [NAS]::DriveName
        $nasIP = [NAS]::IP
        $nasUser = [NAS]::User
        $nasPassword = [NAS]::Password
        $fullPath = "$nasIP\$path"

        Write-Host "Verificando conexiones previas a $nasIP..."
        try {
            cmd /c "net use * /delete /y" | Out-Null
        } catch {
            Write-Host "No habia conexiones SMB previas."
        }

        Write-Host "Conectandose a la NAS: $fullPath..."
        $result = cmd /c "net use $($nasDriveName): $fullPath $nasPassword /user:$nasUser /persistent:no"

        if (-not (Test-Path "$($nasDriveName):\")) {
            throw "No se pudo acceder al recurso compartido $fullPath.`nResultado: $result"
        }

        Write-Host "Conectado a $fullPath en $($nasDriveName):"

        return (Get-PSDrive Z)
    }

    # Elimina la unidad de la NAS en la sesion
    static [void] Disconnect() {
        $nasDriveName = [NAS]::DriveName
        Remove-PSDrive -Name $nasDriveName -Force -ErrorAction SilentlyContinue
    }
}

# Configuracion de red IPv4
class IPConfiguration {
    [string] $InterfaceAlias
    [string] $MACAddress
    [string] $IPAddress
    [int] $PrefixLength
    [string] $Gateway
    [string[]] $DNS
    [bool] $IsDHCP

    IPConfiguration(
        [string]$interfaceAlias,
        [string]$macAddress,
        [string]$ipAddress,
        [int]$prefixLength,
        [string]$gateway,
        [string[]]$dns,
        [bool]$isDHCP
    ) {
        $this.InterfaceAlias = $interfaceAlias
        $this.MACAddress = $macAddress
        $this.IPAddress = $ipAddress
        $this.PrefixLength = $prefixLength
        $this.Gateway = $gateway
        $this.DNS = $dns
        $this.IsDHCP = $isDHCP
    }

    # Crea una instancia a partir del adaptador activo
    static [IPConfiguration] FromAdapter($adapter) {
        $ipv4 = $adapter.IPv4Address[0]

        # Detectar si el adaptador usa DHCP
        $dhcp = (Get-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv4).Dhcp -eq 'Enabled'

        return [IPConfiguration]::new(
            $adapter.InterfaceAlias,
            $adapter.NetAdapter.MacAddress,
            $ipv4.IPAddress,
            $ipv4.PrefixLength,
            $adapter.IPv4DefaultGateway.NextHop,
            $adapter.DnsServer.ServerAddresses,
            $dhcp
        )
    }

    # Crea una instancia a partir de una cadena JSON
    static [IPConfiguration] FromJson([string]$json) {
        $obj = $json | ConvertFrom-Json
        return [IPConfiguration]::new(
            $obj.InterfaceAlias,
            $obj.MACAddress,
            $obj.IPAddress,
            [int]$obj.PrefixLength,
            $obj.Gateway,
            $obj.DNS,
            [bool]$obj.IsDHCP
        )
    }

    # Convierte el objeto a formato JSON
    [string] ToJson() {
        return ($this | ConvertTo-Json -Depth 3 -Compress)
    }

    # Aplica la configuración de red en el sistema
    [void] Apply() {
        if ($this.IsDHCP) {
            # Habilitar DHCP para IPv4
            Set-NetIPInterface -InterfaceAlias $this.InterfaceAlias -Dhcp Enabled -ErrorAction Stop

            # Establecer DNS automático también
            Set-DnsClientServerAddress -InterfaceAlias $this.InterfaceAlias -ResetServerAddresses -ErrorAction Stop
        } else {
            # Limpiar IP previas
            Get-NetIPAddress -InterfaceAlias $this.InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
            Get-NetRoute -InterfaceAlias $this.InterfaceAlias -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

            # Asignar nueva IP
            New-NetIPAddress -InterfaceAlias $this.InterfaceAlias -IPAddress $this.IPAddress `
                -PrefixLength $this.PrefixLength -DefaultGateway $this.Gateway -ErrorAction Stop

            # Asignar DNS
            Set-DnsClientServerAddress -InterfaceAlias $this.InterfaceAlias -ServerAddresses $this.DNS -ErrorAction Stop
        }
    }

    [string] ToString() {
        $dhcpMode = if ($this.IsDHCP) { "Si" } else { "No" }
        $dnsList = if ($this.DNS -and $this.DNS.Count -gt 0) {
            ($this.DNS -join ", ")
        } else {
            "Ninguno"
        }

        return @"
Interfaz         : $($this.InterfaceAlias)
MAC              : $($this.MACAddress)
DHCP             : $dhcpMode
Direccion IP     : $($this.IPAddress)
Prefijo          : /$($this.PrefixLength)
Puerta de enlace : $($this.Gateway)
DNS              : $dnsList
"@
    }
}
