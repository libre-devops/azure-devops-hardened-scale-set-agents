# Check if multiple files exist
function Test-PathExists {
    param(
        [string[]]$Paths
    )

    foreach ($Path in $Paths) {
        if (-not (Test-Path $Path)) {
            _LogMessage -Level "ERROR" -Message "File not found: $Path" -InvocationName $MyInvocation.MyCommand.Name
        } else {
            _LogMessage -Level "INFO" -Message "Found file: $Path" -InvocationName $MyInvocation.MyCommand.Name
        }
    }
}

# Check if multiple programs are installed
function Get-InstalledPrograms {
    param(
        [string[]]$Programs
    )

    foreach ($Program in $Programs) {
        $programPath = Get-Command $Program -ErrorAction SilentlyContinue
        if (-not $programPath) {
            _LogMessage -Level "ERROR" -Message "Program not found: $Program" -InvocationName $MyInvocation.MyCommand.Name
        } else {
            _LogMessage -Level "INFO" -Message "Found program: $Program" -InvocationName $MyInvocation.MyCommand.Name
        }
    }
}

# Generate a new password
function New-Password {
    param (
        [int] $partLength = 5,  # Length of each part of the password
        [string] $alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+<>,.?/:;~`-=',
        [string] $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        [string] $lower = 'abcdefghijklmnopqrstuvwxyz',
        [string] $numbers = '0123456789',
        [string] $special = '!@#$%^&*()_+<>,.?/:;~`-='
    )

    # Helper function to generate a random sequence from the alphabet
    function Generate-RandomSequence {
        param (
            [int] $length,
            [string] $alphabet
        )

        $sequence = New-Object char[] $length
        for ($i = 0; $i -lt $length; $i++) {
            $randomIndex = Get-Random -Minimum 0 -Maximum $alphabet.Length
            $sequence[$i] = $alphabet[$randomIndex]
        }

        return $sequence -join ''
    }

    try {
        # Ensure each part has at least one character of each type
        $minLength = 4
        if ($partLength -lt $minLength) {
            _LogMessage -Level "ERROR" -Message "Each part of the password must be at least $minLength characters to ensure complexity." -InvocationName "$($MyInvocation.MyCommand.Name)"
            throw "Invalid password part length. Must be at least $minLength."
        }

        _LogMessage -Level "INFO" -Message "Generating password with part length $partLength." -InvocationName "$($MyInvocation.MyCommand.Name)"

        $part1 = Generate-RandomSequence -length $partLength -alphabet $alphabet
        $part2 = Generate-RandomSequence -length $partLength -alphabet $alphabet
        $part3 = Generate-RandomSequence -length $partLength -alphabet $alphabet

        # Ensuring at least one character from each category in each part
        $part1 = $upper[(Get-Random -Maximum $upper.Length)] + $part1.Substring(1)
        $part2 = $lower[(Get-Random -Maximum $lower.Length)] + $part2.Substring(1)
        $part3 = $numbers[(Get-Random -Maximum $numbers.Length)] + $special[(Get-Random -Maximum $special.Length)] + $part3.Substring(2)

        # Concatenate parts with separators
        $password = "$part1-$part2-$part3"

        _LogMessage -Level "INFO" -Message "Password generated successfully." -InvocationName "$($MyInvocation.MyCommand.Name)"

        return $password
    }
    catch {
        _LogMessage -Level "ERROR" -Message "An error occurred during password generation: $_" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw
    }
}

# Check if multiple environment variables exist
function Test-EnvironmentVariablesExist {
    param (
        [string[]]$EnvVars  # List of environment variable names to test
    )

    try {
        foreach ($envVar in $EnvVars) {
            # Use Get-Item to access the environment variable dynamically
            $envValue = (Get-Item "env:$envVar" -ErrorAction SilentlyContinue)

            if ($null -eq $envValue) {
                _LogMessage -Level "ERROR" -Message "Environment variable '$envVar' not found." -InvocationName "$($MyInvocation.MyCommand.Name)"
                throw "Environment variable '$envVar' not found."
            } else {
                _LogMessage -Level "INFO" -Message "Environment variable '$envVar' exists." -InvocationName "$($MyInvocation.MyCommand.Name)"
            }
        }
    }
    catch {
        _LogMessage -Level "ERROR" -Message "Error occurred while checking environment variables: $_" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw
    }
}

# Convert string to boolean
function ConvertTo-Boolean {
    param (
        [string]$value
    )
    try {
        $valueLower = $value.ToLower()
        if ($valueLower -eq "true") {
            _LogMessage -Level "INFO" -Message "Successfully converted '$value' to $true." -InvocationName "$($MyInvocation.MyCommand.Name)"
            return $true
        }
        elseif ($valueLower -eq "false") {
            _LogMessage -Level "INFO" -Message "Successfully converted '$value' to $false." -InvocationName "$($MyInvocation.MyCommand.Name)"
            return $false
        }
        else {
            _LogMessage -Level "ERROR" -Message "Invalid value '$value' provided for boolean conversion. Expected 'true' or 'false'." -InvocationName "$($MyInvocation.MyCommand.Name)"
            exit 1
        }
    }
    catch {
        _LogMessage -Level "ERROR" -Message "Error occurred while converting '$value' to boolean: $_" -InvocationName "$($MyInvocation.MyCommand.Name)"
        exit 1
    }
}

# Parse Azure Resource ID to extract Subscription ID, Resource Group, and NSG name
function Convert-AzureResourceId {
    param (
        [string]$ResourceId
    )

    $splitId = $ResourceId -split "/"

    # Ensure that the resource ID has enough parts
    if ($splitId.Length -ge 9) {
        $subscriptionId = $splitId[2]
        $resourceGroup = $splitId[4]
        $nsgName = $splitId[-1]
        return @{ SubscriptionId = $subscriptionId; ResourceGroup = $resourceGroup; NsgName = $nsgName }
    } else {
        _LogMessage -Level "ERROR" -Message "Invalid Azure resource ID format." -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw "Invalid Azure resource ID format."
    }
}


# Export functions
Export-ModuleMember -Function Test-PathExists, Get-InstalledPrograms, New-Password, Test-EnvironmentVariablesExist, ConvertTo-Boolean, Convert-AzureResourceId
