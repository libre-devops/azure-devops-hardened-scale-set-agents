# Packer Module

# Run 'packer init'
function Invoke-PackerInit {
    param (
        [string]$TemplatePath
    )

    if (-not (Test-Path $TemplatePath)) {
        _LogMessage -Level "ERROR" -Message "Packer template file not found: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw "Packer template file not found: $TemplatePath"
    }

    _LogMessage -Level "INFO" -Message "Initializing Packer template: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
    & packer init $TemplatePath
}

# Run 'packer validate'
function Invoke-PackerValidate {
    param (
        [string]$TemplatePath
    )

    if (-not (Test-Path $TemplatePath)) {
        _LogMessage -Level "ERROR" -Message "Packer template file not found: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw "Packer template file not found: $TemplatePath"
    }

    _LogMessage -Level "INFO" -Message "Validating Packer template: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
    & packer validate $TemplatePath
}

# Run 'packer build'
function Invoke-PackerBuild {
    param (
        [string]$TemplatePath
    )

    if (-not (Test-Path $TemplatePath)) {
        _LogMessage -Level "ERROR" -Message "Packer template file not found: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw "Packer template file not found: $TemplatePath"
    }

    _LogMessage -Level "INFO" -Message "Building image with Packer template: $TemplatePath" -InvocationName "$($MyInvocation.MyCommand.Name)"
    & packer build $TemplatePath
}

function Invoke-PackerWorkflow {
    param (
        [string]$TemplatePath
    )

    try {
        _LogMessage -Level "INFO" -Message "Starting Packer workflow." -InvocationName "$($MyInvocation.MyCommand.Name)"

        Invoke-PackerInit -TemplatePath $TemplatePath
        if ($LASTEXITCODE -ne 0) {
            throw "Packer init failed. Aborting workflow."
        }

        Invoke-PackerValidate -TemplatePath $TemplatePath
        if ($LASTEXITCODE -ne 0) {
            throw "Packer validate failed. Aborting workflow."
        }

        Invoke-PackerBuild -TemplatePath $TemplatePath
        if ($LASTEXITCODE -ne 0) {
            throw "Packer build failed. Aborting workflow."
        }

        _LogMessage -Level "INFO" -Message "Packer workflow completed successfully." -InvocationName "$($MyInvocation.MyCommand.Name)"
    }
    catch {
        _LogMessage -Level "ERROR" -Message "Packer workflow failed: $_" -InvocationName "$($MyInvocation.MyCommand.Name)"
        exit 1  # Ensure the script exits with failure status
    }
}

# Export functions
Export-ModuleMember -Function Invoke-PackerInit, Invoke-PackerValidate, Invoke-PackerBuild, Invoke-PackerWorkflow
