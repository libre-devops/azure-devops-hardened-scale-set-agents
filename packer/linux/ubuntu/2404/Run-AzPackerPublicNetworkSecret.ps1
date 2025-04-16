param (
    [bool]$ManualRun = $false, # By default, this script should run as a pipeline, this flag exists for when it is not
    [string]$PackerTemplatePath = "$(Get-Location)/packer/linux/ubuntu/2404/packer.pkr.hcl",
    [string]$NsgId = "/subscriptions/bf6128f4-93cb-45d4-bc13-7b3be2eea1c5/resourceGroups/rg-libd-uks-dev-mgmt/providers/Microsoft.Network/networkSecurityGroups/nsg-libd-uks-dev-mgmt-01" # The ID of the NSG to add the rule to
)

# Get timestamp in "HH:mm:ss" format
$timestamp = Get-Date -Format "HH:mm:ss"

## Setup script modules etc

# Get script directory
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Import all required modules
$modules = @("Logger", "Utils", "AzureLogin", "Keyvault", "Nsg", "Packer")
foreach ($module in $modules) {
    $modulePath = "$scriptDir\PowerShellModules\$module.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction Stop
    } else {
        Write-Host "ERROR: $timestamp - [$($MyInvocation.MyCommand.Name)] Module not found: $modulePath" -ForegroundColor Red
        exit 1
    }
}

# Log that modules were loaded
_LogMessage -Level "INFO" -Message "$timestamp - [$( $MyInvocation.MyCommand.Name )] Modules loaded successfully" -InvocationName "$($MyInvocation.MyCommand.Name)"

# Test pre-requisites are done
Get-InstalledPrograms -Programs @("packer", "az", "ansible")

# Only run 0login and environment checks if ManualRun is true
if ($ManualRun) {
    # Check if already logged in to Az PowerShell (handled by Test-AzCliConnection)
    _LogMessage -Level "INFO" -Message "Checking Azure-Cli authentication..." -InvocationName "$($MyInvocation.MyCommand.Name)"
    Test-AzureCliConnection
}

# Generate a password
$Password = New-Password

#Add passwrd as env variable
$env:PKR_VAR_install_password = $Password

# Check environment variables
Test-EnvironmentVariablesExist -EnvVars @(
    "PKR_VAR_ARM_CLIENT_ID",
    "PKR_VAR_ARM_TENANT_ID",
    "PKR_VAR_ARM_SUBSCRIPTION_ID",
    "PKR_VAR_ARM_CLIENT_SECRET"
)

Test-PathExists -Paths @($PackerTemplatePath)

try
{
    # Parse the Azure resource ID 0to extract the Subscription ID, Resource Group, and NSG name
    $parsedId = Convert-AzureResourceId -ResourceId $NsgId

    $SubscriptionId = $parsedId.SubscriptionId
    $ResourceGroup = $parsedId.ResourceGroup
    $NsgName = $parsedId.NsgName

    Test-AzureCliConnection

    Set-CurrentIPInNsg -ResourceGroup $ResourceGroup `
                      -NsgName $NsgName `
                      -AddRule $true `
                      -RuleName "PackerBuild" `
                      -Priority 1000 `
                      -Direction "Inbound" `
                      -Access "Allow"

    # Run the Packer workflow
    Invoke-PackerWorkflow -TemplatePath $PackerTemplatePath
}
catch
{
    _LogMessage -Level "ERROR" -Message "An error occurred: $_" -InvocationName "$($MyInvocation.MyCommand.Name)"
    throw
}
finally
{
    Set-CurrentIPInNsg -ResourceGroup $ResourceGroup `
                      -NsgName $NsgName `
                      -AddRule $false `
                      -RuleName "PackerBuild" `
                      -Priority 1000 `
                      -Direction "Inbound" `
                      -Access "Allow" `
}

