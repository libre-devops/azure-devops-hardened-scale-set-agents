param(
    [string]$AttemptAzLogin = "true",

    [Parameter(Mandatory = $true)]
    [string]$ScaleSetId
)

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

function ResourceId-Parser($value)
{
    param (
        [string]$ResourceId
    )

    $resourceIdParts = $ResourceId -split '/'
    $subscriptionId = $resourceIdParts[2]
    $resourceGroupName = $resourceIdParts[4]
    $resourceName = $resourceIdParts[-1]

    return [PSCustomObject]@{
        SubscriptionId = $subscriptionId
        ResourceGroupName = $resourceGroupName
        ResourceName = $resourceName
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

$ConvertedAttemptAzLogin = Convert-ToBoolean $AttemptAzLogin


try
{
    if ($ConvertedAttemptAzLogin)
    {
        Connect-AzAccountWithServicePrincipal `
        -ApplicationId $Env:PKR_VAR_ARM_CLIENT_ID `
        -TenantId $Env:PKR_VAR_ARM_TENANT_ID `
        -Secret $Env:PKR_VAR_ARM_CLIENT_SECRET `
        -SubscriptionId $Env:PKR_VAR_ARM_SUBSCRIPTION_ID
    }

    $ScaleSetValues = ResourceId-Parser -ResourceId $ScaleSetId
    Update-AzVmssInstance -ResourceGroupName $ScaleSetValues.ResourceGroupName -VMScaleSetName $ScaleSetValues.$ResourceName -InstanceId "*" -AsJob
}
catch
{
    Write-Error "Error: Exception has occured $_"
}
