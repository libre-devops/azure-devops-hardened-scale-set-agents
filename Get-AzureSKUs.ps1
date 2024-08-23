param (
    [string]$ApplicationId = $env:ARM_CLIENT_ID,
    [string]$TenantId = $env:ARM_TENANT_ID,
    [string]$Secret = $env:ARM_CLIENT_SECRET,
    [string]$SubscriptionId = $env:ARM_SUBSCRIPTION_ID,
    [string]$Location = "uksouth",
    [Parameter(Mandatory = $true)]
    [string]$PublisherName,
    [Parameter(Mandatory = $true)]
    [string]$OfferName,
    [string]$OutputToJson = $null
)

function Connect-AzAccountWithServicePrincipal {
    param (
        [string]$ApplicationId,
        [string]$TenantId,
        [string]$Secret,
        [string]$SubscriptionId
    )

    if (-not $ApplicationId -or -not $TenantId -or -not $Secret -or -not $SubscriptionId) {
        Write-Error "Service principal details and subscription ID must be provided either via parameters or environment variables."
        exit
    }

    try {
        $SecureSecret = $Secret | ConvertTo-SecureString -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($ApplicationId, $SecureSecret)
        Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantId -ErrorAction Stop
        Set-AzContext -SubscriptionId $SubscriptionId

        Write-Host "Successfully logged in to Azure." -ForegroundColor Cyan
    }
    catch {
        Write-Error "Failed to log in to Azure with the provided service principal details: $_"
        throw $_
    }
}

function Get-AzureOSSku {
    param (
        [string]$Location,
        [string]$PublisherName,
        [string]$OfferName,
        [string]$OutputToJson
    )

    $skus = Get-AzVMImageSku -Location $Location -PublisherName $PublisherName -Offer $OfferName

    if (-not [string]::IsNullOrWhiteSpace($OutputToJson)) {
        $skus | Select-Object -ExpandProperty Skus | ConvertTo-Json | Out-File -FilePath $OutputToJson
        Write-Host "Output written to JSON file: $OutputToJson" -ForegroundColor Green
    } else {
        $skus | Select-Object -ExpandProperty Skus
    }
}

# Execute functions with parameters
Connect-AzAccountWithServicePrincipal -ApplicationId $ApplicationId -TenantId $TenantId -Secret $Secret -SubscriptionId $SubscriptionId
Get-AzureOSSku -Location $Location -PublisherName $PublisherName -OfferName $OfferName -OutputToJson $OutputToJson
