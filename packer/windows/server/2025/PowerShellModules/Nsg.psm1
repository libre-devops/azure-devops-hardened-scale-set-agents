function Set-CurrentIPInNsg
{
    param (
        [string]$ResourceGroup,   # Accept the resource group as a parameter
        [string]$NsgName,         # Accept the NSG name as a parameter
        [bool]$AddRule,
        [string]$RuleName,
        [int]$Priority,
        [string]$Direction,
        [string]$Access,
        [string]$Protocol = "Tcp",
        [string]$SourcePortRange = "*",
        [string]$DestinationPortRange = "*",
        [string]$DestinationAddressPrefix = "VirtualNetwork"
    )

    try
    {
        if ($AddRule)
        {
            $currentIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
            if (-not $currentIp)
            {
                _LogMessage -Level "ERROR" -Message "Failed to obtain current IP." -InvocationName "$($MyInvocation.MyCommand.Name)"
                return
            }

            $sourceAddressPrefix = $currentIp

            # Check if the rule already exists using Azure CLI
            $existingRule = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --query "[?name=='$RuleName']" -o tsv

            if ($existingRule)
            {
                _LogMessage -Level "INFO" -Message "Rule $RuleName already exists. Updating it with the new IP address." -InvocationName "$($MyInvocation.MyCommand.Name)"
                # Remove existing rule to update
                az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NsgName --name $RuleName
            }

            # Adding the rule using Azure CLI
            az network nsg rule create --resource-group $ResourceGroup `
                                        --nsg-name $NsgName `
                                        --name $RuleName `
                                        --access $Access `
                                        --protocol $Protocol `
                                        --direction $Direction `
                                        --priority $Priority `
                                        --source-address-prefixes $sourceAddressPrefix `
                                        --source-port-ranges "*" `
                                        --destination-address-prefixes "VirtualNetwork" `
                                        --destination-port-ranges "*"

            _LogMessage -Level "INFO" -Message "Rule $RuleName has been added/updated successfully." -InvocationName "$($MyInvocation.MyCommand.Name)"
        }
        else
        {
            # Removing the rule using Azure CLI
            $existingRule = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --query "[?name=='$RuleName']" -o tsv
            if ($existingRule)
            {
                az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NsgName --name $RuleName
                _LogMessage -Level "INFO" -Message "Rule $RuleName has been removed successfully." -InvocationName "$($MyInvocation.MyCommand.Name)"
            }
            else
            {
                _LogMessage -Level "INFO" -Message "Rule $RuleName does not exist. No action needed." -InvocationName "$($MyInvocation.MyCommand.Name)"
            }
        }

        # Applying changes to the NSG is automatically handled by Azure CLI when rules are added/removed

        _LogMessage -Level "INFO" -Message "NSG has been updated successfully." -InvocationName "$($MyInvocation.MyCommand.Name)"
    }
    catch
    {
        _LogMessage -Level "ERROR" -Message "An error occurred: $_" -InvocationName "$($MyInvocation.MyCommand.Name)"
        throw
    }
}

Export-ModuleMember -Function Set-CurrentIPInNsg
