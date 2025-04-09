function Connect-AzureUser
{
    try
    {
        $context = Get-AzContext
        if ($null -eq $context -or $null -eq $context.Account)
        {
            _LogMessage -Level "INFO" -Message "No existing Azure context found. Authenticating to Azure..." -InvocationName $MyInvocation.MyCommand.Name
            Connect-AzAccount -ErrorAction Stop
            _LogMessage -Level "INFO" -Message "Authentication successful." -InvocationName $MyInvocation.MyCommand.Name
        }
        else
        {
            _LogMessage -Level "INFO" -Message "Already authenticated to Azure as $( $context.Account.Id )." -InvocationName $MyInvocation.MyCommand.Name
        }
    }
    catch
    {
        _LogMessage -Level "ERROR" -Message "Authentication failed. $( $_.Exception.Message )" -InvocationName $MyInvocation.MyCommand.Name
        throw
    }
}

function Connect-ToAzureSpn
{
    param(
        [bool]$UseSPN,
        [string]$ClientId,
        [string]$TenantId,
        [string]$ClientSecret
    )

    if ($UseSPN)
    {
        _LogMessage -Level "INFO" -Message "Connecting with Service Principal..." -InvocationName $MyInvocation.MyCommand.Name
        $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($ClientId, $securePassword)
        Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $credential
    }
    else
    {
        Connect-AzureUser
    }
}

function Connect-ToAzureCliOidc
{
    param(
        [string]$ClientId,
        [string]$TenantId,
        [string]$OidcToken
    )

    try
    {
        # Run az login to authenticate with Azure CLI
        az login --service-principal --username ${ClientId} --tenant ${TenantId} --allow-no-subscriptions --federated-token ${OidcToken}
    }
    catch
    {
        _LogMessage -Level "ERROR" -Message "Azure CLI is not installed or there was an error running the command" -InvocationName "$( $MyInvocation.MyCommand.Name )"
        exit 1
    }
}

function Test-AzureCliConnection
{
    try
    {
        # Run az account show to check if Azure CLI is authenticated
        $azureStatus = az account show --query "id" -o tsv

        if ($azureStatus)
        {
            _LogMessage -Level "INFO" -Message "Successfully connected to Azure via Azure-Cli" -InvocationName "$( $MyInvocation.MyCommand.Name )"
        }
        else
        {
            _LogMessage -Level "ERROR" -Message "Not authenticated with Azure CLI" -InvocationName "$( $MyInvocation.MyCommand.Name )"
            exit 1
        }
    }
    catch
    {
        _LogMessage -Level "ERROR" -Message "Azure CLI is not installed or there was an error running the command" -InvocationName "$( $MyInvocation.MyCommand.Name )"
        exit 1
    }
}

function Test-AzPowerShellConnection
{
    try
    {
        # Get the current Az context to check if authenticated
        $azContext = Get-AzContext

        if ($azContext -and $azContext.Account)
        {
            _LogMessage -Level "INFO" -Message "Successfully connected to Azure via Az PowerShell" -InvocationName "$( $MyInvocation.MyCommand.Name )"
        }
        else
        {
            _LogMessage -Level "ERROR" -Message "Not authenticated with Az PowerShell" -InvocationName "$( $MyInvocation.MyCommand.Name )"
            exit 1
        }
    }
    catch
    {
        _LogMessage -Level "ERROR" -Message "Az PowerShell module is not installed or there was an error checking the connection" -InvocationName "$( $MyInvocation.MyCommand.Name )"
        exit 1
    }
}


# Export functions
Export-ModuleMember -Function Connect-AzureUser, Connect-ToAzureSpn, Connect-ToAzureCliOidc, Test-AzureCliConnection, Test-AzPowerShellConnection
