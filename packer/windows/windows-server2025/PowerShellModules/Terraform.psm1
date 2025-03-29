# Run 'terraform validate'
function Invoke-TerraformValidate {
    param (
        [string]$CodePath
    )

    if (-not (Test-Path $CodePath)) {
        _LogMessage -Level "ERROR" -Message "Terraform code not found: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw "Terraform code not found: $CodePath"
    }

    _LogMessage -Level "INFO" -Message "Validating Terraform: $CodePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
    Set-Location $CodePath
    & terraform validate
}

# Run 'terraform validate'
function Invoke-TerraformFmtCheck {
    param (
        [string]$CodePath
    )

    if (-not (Test-Path $CodePath)) {
        _LogMessage -Level "ERROR" -Message "Terraform code not found: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw "Terraform code not found: $CodePath"
    }

    _LogMessage -Level "INFO" -Message "Validating Terraform: $CodePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
    Set-Location $CodePath
    & terraform fmt -check
}

Export-ModuleMember -Function Invoke-TerraformValidate, Invoke-TerraformFmtCheck
