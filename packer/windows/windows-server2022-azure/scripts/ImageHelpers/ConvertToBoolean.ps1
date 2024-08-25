function Convert-ToBoolean($value)
{
    $valueLower = $value.ToLower()
    if ($valueLower -eq "true")
    {
        return $true
    }
    elseif ($valueLower -eq "false")
    {
        return $false
    }
    else
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Invalid value - $value. Exiting."
        exit 1
    }
}
