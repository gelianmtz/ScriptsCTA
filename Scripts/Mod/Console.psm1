function Read-Input {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [ScriptBlock]$Predicate,

        [string]$Default,

        [ValidateSet("Retry", "Throw")]
        [string]$OnInvalid = "Retry"
    )

    # Si no se proporciono predicado, cualquier entrada es considerada valida
    if (-not $Predicate) {
        $Predicate = { param($x) return $true }
    }

    # Validar el valor por defecto si se proporciono
    if ($PSBoundParameters.ContainsKey('Default')) {
        if (-not (& $Predicate $Default)) {
            throw "El valor por defecto '$Default' no cumple con el predicado."
        }
    }

    while ($true) {
        # Mostrar el prompt con valor por defecto (si existe)
        if ($PSBoundParameters.ContainsKey('Default')) {
            $displayPrompt = "$Prompt [$Default]"
        } else {
            $displayPrompt = $Prompt
        }

        # Leer entrada y recortar espacios
        $inputValue = (Read-Host $displayPrompt).Trim()

        # Manejar entrada vacia
        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            if ($PSBoundParameters.ContainsKey('Default')) {
                return $Default
            } else {
                $message = "Valor vacio."
                if ($OnInvalid -eq "Throw") {
                    throw $message
                } else {
                    Write-Host $message
                    continue
                }
            }
        }

        # Validar usando el predicado
        if (& $Predicate $inputValue) {
            return $inputValue
        } else {
            $message = "Valor invalido: '$inputValue'."
            if ($OnInvalid -eq "Throw") {
                throw $message
            } else {
                Write-Host $message
            }
        }
    }

    <#
        .SYNOPSIS
        Prompts the user for input and validates the response using an optional predicate.

        .DESCRIPTION
        The Read-Input function displays a prompt to the user and reads a value from input.  
        The value can be validated using a custom predicate script block.  
        If the input is invalid, the function can either retry or throw an exception depending 
        on the OnInvalid parameter.  
        A default value can also be provided, which is used if the user submits an empty response.

        .PARAMETER Prompt
        The message displayed to the user when asking for input.

        .PARAMETER Predicate
        An optional script block used to validate the user input.  
        It should accept a single parameter (the input value) and return $true if valid, $false otherwise.  
        If not specified, all input values are considered valid.

        .PARAMETER Default
        The default value used if the user provides no input.  
        This value must satisfy the predicate if one is defined.

        .PARAMETER OnInvalid
        Determines what happens when input fails validation.  
        Accepted values:
        - "Retry": Displays an error message and prompts again (default behavior).
        - "Throw": Throws an exception and stops execution.

        .OUTPUTS
        System.String
        The function returns the user-provided input or the default value, if applicable.

        .EXAMPLE
        PS> Read-Input -Prompt "Enter your name"
        Enter your name: John
        John

        .EXAMPLE
        PS> Read-Input -Prompt "Enter your age" -Predicate { param($x) $x -match '^\d+$' }
        Enter your age: abc
        Invalid value: 'abc'.
        Enter your age: 25
        25

        .EXAMPLE
        PS> Read-Input -Prompt "Enter your country" -Default "USA"
        Enter your country [USA]:
        USA

        .EXAMPLE
        PS> Read-Input -Prompt "Enter a value" -Predicate { param($x) $x -in 'A','B','C' } -OnInvalid Throw
        Enter a value: D
        throw : Invalid value: 'D'.
    #>
}

function Confirm-Operation {
    param([Parameter(Mandatory = $true)][string]$Message)

    $confirm = Read-Host "$Message (S/N)"
    if ($confirm -notin @('S', 's')) {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        exit
    }

    <#
        .SYNOPSIS
        Displays a confirmation prompt requiring a Yes/No response.

        .DESCRIPTION
        The Confirm-Operation function prompts the user to confirm an action.
        The user must type 'S' or 's' to indicate affirmative confirmation.
        Any other response results in the operation being cancelled and the
        script terminating.

        .PARAMETER Message
        The message displayed to the user before the confirmation prompt.

        .EXAMPLE
        PS> Confirm-Operation -Message "Do you want to continue?"
        Do you want to continue? (S/N): S

        .EXAMPLE
        PS> Confirm-Operation -Message "Delete all files?"
        Delete all files? (S/N): N
        Operation cancelled.
    #>
}

function Exit-Program {
    Write-Host "Presiona cualquier tecla para salir..."
    [void][System.Console]::ReadKey($true)
    exit

    <#
        .SYNOPSIS
        Waits for a key press and exits the script.

        .DESCRIPTION
        The Exit-Program function displays a message prompting the user to
        press any key. After a key is pressed, the function terminates the script.
    #>
}
