function Install-TenvPackages {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Packages
    )

    if (-not $Packages) {
        return
    }

    Write-Host "$Install tenv packages"
    pacman.exe -S --noconfirm --needed --noprogressbar $Packages

}

function Install-MingwPackages {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]] $Packages
    )

    if (-not $Packages) {
        return
    }

    Write-Host "$logPrefix Install mingw packages"
    $archs = $Packages.arch

    foreach ($arch in $archs) {
        Write-Host "Installing $arch packages"
        $archPackages = $toolsetContent.mingw | Where-Object { $_.arch -eq $arch }
        $runtimePackages = $archPackages.runtime_packages.name | ForEach-Object { "${arch}-$_" }
        $additionalPackages = $archPackages.additional_packages | ForEach-Object { "${arch}-$_" }
        $packagesToInstall = $runtimePackages + $additionalPackages
        Write-Host "The following packages will be installed: $packagesToInstall"
        pacman.exe -S --noconfirm --needed --noprogressbar $packagesToInstall
        if ($LastExitCode -ne 0) {
            throw "Installation of $arch packages failed with exit code $LastExitCode"
        }
    }

    # clean all packages to decrease image size
    Write-Host "$logPrefix Clean packages"
    pacman.exe -Scc --noconfirm
    if ($LastExitCode -ne 0) {
        throw "Cleaning of packages failed with exit code $LastExitCode"
    }

    $pkgs = pacman.exe -Q
    if ($LastExitCode -ne 0) {
        throw "Listing of packages failed with exit code $LastExitCode"
    }

    foreach ($arch in $archs) {
        Write-Host "$logPrefix Installed $arch packages"
        $pkgs | Select-String -Pattern "^${arch}-"
    }
}

Install-Msys2

# Add msys2 bin tools folders to PATH temporary
$env:PATH = "C:\msys64\mingw64\bin;C:\msys64\usr\bin;$origPath"

Write-Host "$logPrefix pacman --noconfirm -Syyuu"
pacman.exe -Syyuu --noconfirm
if ($LastExitCode -ne 0) {
    throw "Updating of packages failed with exit code $LastExitCode"
}
taskkill /f /fi "MODULES eq msys-2.0.dll"

Write-Host "$logPrefix pacman --noconfirm -Syuu (2nd pass)"
pacman.exe -Syuu --noconfirm
if ($LastExitCode -ne 0) {
    throw "Second pass updating of packages failed with exit code $LastExitCode"
}
taskkill /f /fi "MODULES eq msys-2.0.dll"

$toolsetContent = (Get-ToolsetContent).MsysPackages
Install-Msys2Packages -Packages $toolsetContent.msys2
Install-MingwPackages -Packages $toolsetContent.mingw

$env:PATH = $origPath
Write-Host "`nMSYS2 installation completed"

Invoke-PesterTests -TestFile "MSYS2"
