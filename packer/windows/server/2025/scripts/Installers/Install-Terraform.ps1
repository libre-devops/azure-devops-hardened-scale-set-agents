function InstallTerraform($versionConstraint) {
    $escapedVersionConstraint = [regex]::Escape($versionConstraint)

    # Get the latest version that matches the major and minor version constraint
    $version = tenv tf list-remote | Select-String "^${escapedVersionConstraint}\." | Select-Object -Last 1 | ForEach-Object { $_.ToString().Trim() }

    # Clean the version by removing any "(installed)" suffix
    $cleanVersion = $version -replace '\s*\(installed\)\s*', ''

    if ($null -eq $cleanVersion -or $cleanVersion -eq '') {
        Write-Host "No matching version found for constraint $versionConstraint." -ForegroundColor Red
        exit 1
    }

    # Install and use the specific version
    Write-Host "Installing Terraform version $cleanVersion." -ForegroundColor Cyan
    tenv tf install $cleanVersion
    tenv tf use $cleanVersion
}

InstallTerraform '1.9'
InstallTerraform '1.8'
tenv tf install latest
tenv tf use latest
