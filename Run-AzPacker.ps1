# Run-Packer.ps1 -WorkingDirectory "$(Get-Location)//packer/windows/windows-server2022-azure"

param (
    [string]$RunPackerInit = "true",
    [string]$RunPackerValidate = "true",
    [string]$RunPackerBuild = "true",
    [string]$PackerFileName = "packer.pkr.hcl",
    [string]$ForcePackerBuild = "true",
    [string]$WorkingDirectory = (Get-Location).Path,
    [string]$PackerVersion = "default",
    [string]$NsgResourceId = $null,
    [string]$KeyvaultResourceId = $null,
    [string]$AddCurrentClientToNsg = "true",
    [string]$AddCurrentClientToKeyvault = "true",
    [string]$AttemptAzLogin = "true",
    [string]$RuleName = "TemporaryAllowCurrentClientIP",
    [int]$Priority = 105,
    [string]$Direction = "Inbound",
    [string]$Access = "Allow",
    [string]$Protocol = "Tcp",
    [string]$SourcePortRange = "*",
    [string]$DestinationPortRange = "*",
    [string]$DestinationAddressPrefix = "VirtualNetwork"
)

# Function to check if the Packer file exists
function Check-PackerFileExists
{
    $filePath = Join-Path -Path $WorkingDirectory -ChildPath $PackerFileName
    if (-not(Test-Path -Path $filePath))
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer file not found at $filePath. Exiting."
        exit 1
    }
    else
    {
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Packer file found at: $filePath" -ForegroundColor Green
    }
}

function New-Password
{
    param (
        [int] $partLength = 5, # Length of each part of the password
        [string] $alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+<>,.?/:;~`-=',
        [string] $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        [string] $lower = 'abcdefghijklmnopqrstuvwxyz',
        [string] $numbers = '0123456789',
        [string] $special = '!@#$%^&*()_+<>,.?/:;~`-='
    )

    # Helper function to generate a random sequence from the alphabet
    function Generate-RandomSequence
    {
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

    # Ensure each part has at least one character of each type
    $minLength = 4
    if ($partLength -lt $minLength)
    {
        Write-Error "Each part of the password must be at least $minLength characters to ensure complexity."
        return
    }

    $part1 = Generate-RandomSequence -length $partLength -alphabet $alphabet
    $part2 = Generate-RandomSequence -length $partLength -alphabet $alphabet
    $part3 = Generate-RandomSequence -length $partLength -alphabet $alphabet

    # Ensuring at least one character from each category in each part
    $part1 = $upper[(Get-Random -Maximum $upper.Length)] + $part1.Substring(1)
    $part2 = $lower[(Get-Random -Maximum $lower.Length)] + $part2.Substring(1)
    $part3 = $numbers[(Get-Random -Maximum $numbers.Length)] + $special[(Get-Random -Maximum $special.Length)] + $part3.Substring(2)

    # Concatenate parts with separators
    $password = "$part1-$part2-$part3"

    return $password
}



function Update-KeyVaultNetworkRule
{
    param (
        [string]$KeyVaultId,
        [bool]$AddClientIP
    )

    try
    {
        $resourceIdParts = $KeyVaultId -split '/'
        $subscriptionId = $resourceIdParts[2]
        $resourceGroupName = $resourceIdParts[4]
        $keyvaultName = $resourceIdParts[-1]

        $keyVault = Get-AzKeyVault -VaultName $keyvaultName -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId
        $currentNetworkAcls = $keyVault.NetworkAcls

        Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Fetching current IP rules for Key Vault: $KeyVaultName"
        $currentIps = $currentNetworkAcls.IpAddressRanges | ForEach-Object { $_ -replace '/32$', '' }
        Write-Information "[$( $MyInvocation.MyCommand.Name )] Info: Current IP rules: $( $currentIps -join ', ' )"

        $currentIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
        Write-Information "[$( $MyInvocation.MyCommand.Name )] Info: Current client IP: $currentIp"

        $ipAlreadyExists = $currentIps -contains $currentIp
        # Ensure $newIpRules is always treated as an array
        $newIpRules = @($currentIps)

        if ($AddClientIP -and -not$ipAlreadyExists)
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Appending current client IP to existing IP rules." -ForegroundColor Green
            # Use the array addition operator to add a new element to the array
            $newIpRules += $currentIp
            Write-Information "[$( $MyInvocation.MyCommand.Name )] Info: New IP rules are $( $newIpRules -join ', ' )"
        }
        elseif (-not$AddClientIP -and $ipAlreadyExists)
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Removing current client IP from existing IP rules." -ForegroundColor Green
            $newIpRules = $newIpRules | Where-Object { $_ -ne $currentIp }
        }
        else
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: No changes needed for the IP rules." -ForegroundColor Green
            return
        }

        Write-Information "[$( $MyInvocation.MyCommand.Name )] Info: Updating IP rules: $( $newIpRules -join ', ' )"
        # Reapply /32 subnet notation for consistent Azure Key Vault rules format
        $newIpRules = $newIpRules | ForEach-Object { "$_/32" }

        # Ensure $newIpRules is passed as an array of strings
        $newIpRulesArray = @($newIpRules) # This ensures that $newIpRules is treated as an array even if it contains only one element

        Update-AzKeyVaultNetworkRuleSet -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName `
            -IpAddressRange $newIpRulesArray -Bypass $currentNetworkAcls.Bypass -DefaultAction $currentNetworkAcls.DefaultAction

        Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Key Vault network configuration updated." -ForegroundColor Green
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: An error occurred: $_"
    }
}

# Function to check if Tfenv is installed
function Check-PkenvExists
{
    try
    {
        $pkenvPath = Get-Command pkenv -ErrorAction Stop
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: pkenv found at: $( $pkenvPath.Source )" -ForegroundColor Green
        return $true
    }
    catch
    {
        Write-Warning "[$( $MyInvocation.MyCommand.Name )] Warning: pkenv is not installed or not in PATH. Skipping version checking."
        return $false
    }
}

# Function to check if Packer is installed
function Check-PackerExists
{
    try
    {
        $packerPath = Get-Command packer -ErrorAction Stop
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Packer found at: $( $packerPath.Source )" -ForegroundColor Green
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer is not installed or not in PATH. Exiting."
        exit 1
    }
}

# Function to ensure the desired version of Packer is installed
function Ensure-PackerVersion
{
    # Check if the specified version is already installed
    $pkrVersion = $PackerVersion.ToLower()
    if ($pkrVersion -ne 'default')
    {
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Packer version is set to '$PackerVersion', running install and use" -ForegroundColor Green
        pkenv install $pkrVersion
        pkenv use $pkrVersion
    }
    else
    {
        try
        {
            Write-Information "[$( $MyInvocation.MyCommand.Name )] Info: Installing Packer version $Version using pkenv..."
            pkenv install $Version
            pkenv use $Version
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Installed and set Packer version $Version" -ForegroundColor Green
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Failed to install Packer version $Version"
            exit 1
        }
    }
}

# Function to convert string to boolean
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

function Connect-AzAccountWithServicePrincipal
{
    param (
        [string]$ApplicationId,
        [string]$TenantId,
        [string]$Secret,
        [string]$SubscriptionId
    )

    try
    {
        $SecureSecret = $Secret | ConvertTo-SecureString -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($ApplicationId, $SecureSecret)
        Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantId -ErrorAction Stop | Out-Null

        if (-not [string]::IsNullOrEmpty($SubscriptionId))
        {
            Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        }

        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Successfully logged in to Azure." -ForegroundColor Cyan
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Failed to log in to Azure with the provided service principal details: $_"
        throw $_
    }
}

function Manage-CurrentIPInNsg
{
    param (
        [Microsoft.Azure.Commands.Network.Models.PSNetworkSecurityGroup]$Nsg,
        [bool]$AddRule,
        [string]$RuleName,
        [int]$Priority,
        [string]$Direction,
        [string]$Access,
        [string]$Protocol,
        [string]$SourcePortRange,
        [string]$DestinationPortRange,
        [string]$DestinationAddressPrefix
    )

    try
    {
        if ($AddRule)
        {
            $currentIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
            if (-not$currentIp)
            {
                Write-Error "[$( $MyInvocation.MyCommand.Name )] Failed to obtain current IP."
                return
            }

            $sourceAddressPrefix = $currentIp

            # Check if the rule already exists
            $existingRule = $Nsg.SecurityRules | Where-Object { $_.Name -eq $RuleName }

            if ($existingRule)
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName already exists. Updating it with the new IP address." -ForegroundColor Green
                # Remove existing rule to update
                $Nsg.SecurityRules.Remove($existingRule)
            }

            # Adding the rule
            $rule = New-AzNetworkSecurityRuleConfig -Name $RuleName `
                                                    -Access $Access `
                                                    -Protocol $Protocol `
                                                    -Direction $Direction `
                                                    -Priority $Priority `
                                                    -SourceAddressPrefix $sourceAddressPrefix `
                                                    -SourcePortRange $SourcePortRange `
                                                    -DestinationAddressPrefix $DestinationAddressPrefix `
                                                    -DestinationPortRange $DestinationPortRange
            $Nsg.SecurityRules.Add($rule)

            Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName has been added/updated successfully." -ForegroundColor Green
        }
        else
        {
            # Removing the rule
            $existingRule = $Nsg.SecurityRules | Where-Object { $_.Name -eq $RuleName }
            if ($existingRule)
            {
                $Nsg.SecurityRules.Remove($existingRule)
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName has been removed successfully." -ForegroundColor Green
            }
            else
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName does not exist. No action needed." -ForegroundColor Yellow
            }
        }

        # Applying changes to the NSG
        Set-AzNetworkSecurityGroup -NetworkSecurityGroup $Nsg | Out-Null
        Write-Host "[$( $MyInvocation.MyCommand.Name )] NSG has been updated successfully." -ForegroundColor Green
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] An error occurred: $_"
    }
}

function Run-PackerInit
{
    if ($RunPackerInit -eq $true)
    {
        try
        {
            if ($isWindows)
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer init in $WorkingDirectory" -ForegroundColor Green
                packer init -upgrade $PackerFileName | Out-Host
                if ($LASTEXITCODE -eq 0)
                {
                    return $true
                }
                else
                {
                    Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer init failed with exit code $LASTEXITCODE"
                    return $false
                }
            }
            else
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer init in $WorkingDirectory" -ForegroundColor Green
                packer init -force $PackerFileName | Out-Host
                if ($LASTEXITCODE -eq 0)
                {
                    return $true
                }
                else
                {
                    Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer init failed with exit code $LASTEXITCODE"
                    return $false
                }
            }
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer init encountered an exception"
            return $false
        }
    }
    return $false
}


function Run-PackerValidate
{
    if ($RunPackerValidate -eq $true)
    {
        try
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer validate in $WorkingDirectory" -ForegroundColor Green
            packer validate $PackerFileName | Out-Host
            if ($LASTEXITCODE -eq 0)
            {
                return $true
            }
            else
            {
                Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer validate failed with exit code $LASTEXITCODE"
                return $false
            }
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer validate encountered an exception"
            return $false
        }
    }
    return $false
}

function Run-PackerBuild
{
    if ($RunPackerBuild -eq $true)
    {
        try
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer build in $WorkingDirectory" -ForegroundColor Green
            if ($ConvertedForcePackerBuild)
            {
                packer build -force $PackerFileName | Out-Host
            }
            else
            {
                packer build $PackerFileName | Out-Host
            }
            if ($LASTEXITCODE -eq 0)
            {
                return $true
            }
            else
            {
                Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer build failed with exit code $LASTEXITCODE"
                return $false
            }
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer build encountered an exception"
            return $false
        }
    }
    return $false
}


try
{
    $ConvertedAddCurrentClientToNsg = Convert-ToBoolean $AddCurrentClientToNsg
    $ConvertedAddCurrentClientToKeyvault = Convert-ToBoolean $AddCurrentClientToKeyvault
    $ConvertedAttemptAzLogin = Convert-ToBoolean $AttemptAzLogin
    $ConvertedForcePackerBuild = Convert-ToBoolean $ForcePackerBuild

    if ($ConvertedAttemptAzLogin)
    {
        Connect-AzAccountWithServicePrincipal `
        -ApplicationId $Env:PKR_VAR_ARM_CLIENT_ID `
        -TenantId $Env:PKR_VAR_ARM_TENANT_ID `
        -Secret $Env:PKR_VAR_ARM_CLIENT_SECRET `
        -SubscriptionId $Env:PKR_VAR_ARM_SUBSCRIPTION_ID
    }

    if ($null -ne $NsgResourceId)
    {
        # Extract Resource Group Name and NSG Name from the Resource ID
        $resourceIdParts = $NsgResourceId -split '/'
        $resourceGroupName = $resourceIdParts[4]
        $nsgName = $resourceIdParts[-1]

        # Retrieve the NSG object
        $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName

        Manage-CurrentIPInNsg `
        -Nsg $nsg `
        -AddRule $ConvertedAddCurrentClientToNsg `
        -RuleName $RuleName `
        -Priority $Priority `
        -Direction $Direction `
        -Access $Access `
        -Protocol $Protocol `
        -SourcePortRange $SourcePortRange `
        -DestinationPortRange $DestinationPortRange `
        -DestinationAddressPrefix $DestinationAddressPrefix
    }
    else
    {
        Write-Information "[$( $MyInvocation.MyCommand.Name )] NSG ID not supplied, so not editing the NSG"
    }
    if ($null -ne $KeyvaultResourceId)
    {
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Starting script to update Key Vault firewall rules based on AddClientIPToFirewall flag." -ForegroundColor Cyan

        if ($null -ne $KeyvaultResourceId)
        {
            Update-KeyVaultNetworkRule -KeyVaultId $KeyvaultResourceId -AddClientIP $ConvertedAddCurrentClientToKeyvault
        }
        else
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Key Vault Resource ID not properly supplied."
        }
    }
    else
    {
        Write-Information "[$( $MyInvocation.MyCommand.Name )] Key vault ID not supplied, so not editing key vault"
    }
    # Convert string parameters to boolean
    $RunPackerInit = Convert-ToBoolean $RunPackerInit
    $RunPackerValidate = Convert-ToBoolean $RunPackerValidate
    $RunPackerBuild = Convert-ToBoolean $RunPackerBuild

    if ($RunPackerInit -eq $false)
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: You must run packer init to use this script, it does not support false use of it at this time."
        exit 1
    }
    # Change to the specified working directory
    try
    {
        $CurrentWorkingDirectory = (Get-Location).path
        Set-Location -Path $WorkingDirectory
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Unable to change to directory: $WorkingDirectory"
        exit 1
    }

    Check-PackerFileExists

    # Execution flow
    $initSuccess = Run-PackerInit
    if ($initSuccess -eq $true)
    {
        $validateSuccess = Run-PackerValidate
        $packerPassword = New-Password
        Set-Item -Path Env:PKR_VAR_install_password -Value $packerPassword

        if ($validateSuccess -eq $true)
        {
            Run-PackerBuild
        }
        else
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Packer validate failed. Skipping Packer build."
        }
    }
    else
    {
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Packer init failed. Skipping Packer validate and Packer build."
    }

}
catch
{
    Write-Error "[$( $MyInvocation.MyCommand.Name )] An error occurred: $_"
}
finally
{
    if ($null -ne $NsgResourceId)
    {
        # Extract Resource Group Name and NSG Name from the Resource ID
        $resourceIdParts = $NsgResourceId -split '/'
        $resourceGroupName = $resourceIdParts[4]
        $nsgName = $resourceIdParts[-1]

        # Retrieve the NSG object
        $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName
        Manage-CurrentIPInNsg `
        -Nsg $nsg `
        -AddRule $false `
        -RuleName $RuleName `
        -Priority $Priority `
        -Direction $Direction `
        -Access $Access `
        -Protocol $Protocol `
        -SourcePortRange $SourcePortRange `
        -DestinationPortRange $DestinationPortRange `
        -DestinationAddressPrefix $DestinationAddressPrefix
    }
    else
    {
        Write-Information "[$( $MyInvocation.MyCommand.Name )] NSG ID not supplied, so not editing the NSG"
    }
    if ($null -ne $KeyvaultResourceId)
    {
        Write-Host "Starting script to update Key Vault firewall rules based on AddClientIPToFirewall flag."


        if ($null -ne $KeyvaultResourceId)
        {
            Update-KeyVaultNetworkRule -KeyVaultId $KeyvaultResourceId -AddClientIP $false
        }
        else
        {
            Write-Error "Key Vault Resource ID not properly supplied."
        }
    }
    else
    {
        Write-Information "[$( $MyInvocation.MyCommand.Name )] Key vault ID not supplied, so not editing key vault"
    }
    Set-Location $CurrentWorkingDirectory
}
