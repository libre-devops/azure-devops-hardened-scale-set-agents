param (
    [string]$WorkingDirectory = (Get-Location).Path,
    [string]$ApplicationId,
    [string]$TenantId,
    [string]$Secret,
    [string]$SubscriptionId
)

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

try
{
    Connect-AzAccountWithServicePrincipal -ApplicationId $ApplicationId -SubscriptionId $SubscriptionId -TenantId $TenantId -Secret $Secret

    # List and delete all managed images in the subscription
    $managedImages = Get-AzImage
    foreach ($image in $managedImages)
    {
        Write-Host "Deleting managed image: $( $image.Name ) in resource group: $( $image.ResourceGroupName )"
        # Uncomment the next line to actually perform the deletion
        # Remove-AzImage -ImageName $image.Name -ResourceGroupName $image.ResourceGroupName -Force
    }

    # List all galleries
    $galleries = Get-AzGallery
    foreach ($gallery in $galleries)
    {
        Write-Host "Processing gallery: $( $gallery.Name )"

        # List all image definitions within the gallery
        $imageDefinitions = Get-AzGalleryImageDefinition -ResourceGroupName $gallery.ResourceGroupName -GalleryName $gallery.Name
        foreach ($imageDef in $imageDefinitions)
        {
            Write-Host "Processing image definition: $( $imageDef.Name )"

            # List all image versions for the current image definition
            $imageVersions = Get-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName -GalleryName $gallery.Name -GalleryImageDefinitionName $imageDef.Name
            foreach ($imageVersion in $imageVersions)
            {
                Write-Host "Deleting image version: $( $imageVersion.Name )"
                # Uncomment the next line to actually perform the deletion
                Remove-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName -GalleryName $gallery.Name -GalleryImageDefinitionName $imageDef.Name -GalleryImageVersionName $imageVersion.Name -Force
            }
        }
    }
}
catch
{
    Write-Error "Error: An exception has occurred $_"
}
