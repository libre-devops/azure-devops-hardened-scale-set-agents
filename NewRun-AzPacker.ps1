Import-Module "./PowerShellModules/Logger.psm1" -Force
Import-Module "./PowerShellModules/AzureLogin.psm1" -Force

# Example usage
Connect-ToAzureSpn -UseSPN $true -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret
