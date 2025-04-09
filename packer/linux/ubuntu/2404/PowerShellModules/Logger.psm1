function _LogMessage {
    param(
        [string]$Level,
        [string]$Message,
        [string]$InvocationName
    )
    $timestamp = Get-Date -Format "HH:mm:ss"

    if ($Level -eq "DEBUG" -and -not $global:IsDebugMode) { return }

    switch ($Level) {
        "INFO"    { Write-Host "$( $Level ): $timestamp - [$InvocationName] $Message" -ForegroundColor Cyan }
        "DEBUG"   { Write-Host "$( $Level ): $timestamp - [$InvocationName] $Message" -ForegroundColor Yellow }
        "WARNING" { Write-Host "$( $Level ): $timestamp - [$InvocationName] $Message" -ForegroundColor DarkYellow }
        "ERROR"   { Write-Host "$( $Level ): $timestamp - [$InvocationName] $Message" -ForegroundColor Red }
        default   { Write-Host "$( $Level ): $timestamp - [$InvocationName] $Message" }
    }
}

# Export function
Export-ModuleMember -Function _LogMessage
