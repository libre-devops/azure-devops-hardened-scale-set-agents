function Get-BashVersion {
    $version = bash -c 'echo ${BASH_VERSION}'
    return "Bash $version"
}

function Get-OpensslVersion {
    return "OpenSSL $(dpkg-query -W -f '${Version}' openssl)"
}

function Get-PythonVersion {
    $result = Get-CommandResult "python --version"
    $version = $result.Output | Take-OutputPart -Part 1
    return "Python $version"
}

function Get-Python3Version {
    $result = Get-CommandResult "python3 --version"
    $version = $result.Output | Take-OutputPart -Part 1
    return "Python3 $version"
}

function Get-PowershellVersion {
    return $(pwsh --version)
}

function Get-HomebrewVersion {
    $result = Get-CommandResult "brew -v"
    $result.Output -match "Homebrew (?<version>\d+\.\d+\.\d+)" | Out-Null
    $version = $Matches.version
    return "Homebrew $version"
}

function Get-HelmVersion {
    $(helm version) -match 'Version:"v(?<version>\d+\.\d+\.\d+)"' | Out-Null
    $helmVersion = $Matches.version
    return "Helm $helmVersion"
}



function Get-PipVersion {
    $result = Get-CommandResult "pip --version"
    $result.Output -match "pip (?<version>\d+\.\d+\.\d+)" | Out-Null
    $pipVersion = $Matches.version
    return "Pip $pipVersion"
}

function Get-Pip3Version {
    $result = Get-CommandResult "pip3 --version"
    $result.Output -match "pip (?<version>\d+\.\d+\.\d+)" | Out-Null
    $pipVersion = $Matches.version
    return "Pip3 $pipVersion"
}

function Get-VcpkgVersion {
    $result = Get-CommandResult "vcpkg version"
    $result.Output -match "version (?<version>\d+\.\d+\.\d+)" | Out-Null
    $vcpkgVersion = $Matches.version
    $commitId = git -C "/usr/local/share/vcpkg" rev-parse --short HEAD
    return "Vcpkg $vcpkgVersion (build from master \<$commitId>)"
}

function Get-AzModuleVersions {
    $azModuleVersions = Get-ChildItem /usr/share | Where-Object { $_ -match "az_\d+" } | Foreach-Object {
        $_.Name.Split("_")[1]
    }

    $azModuleVersions = $azModuleVersions -join " "
    return $azModuleVersions
}

function Get-PowerShellModules {
    $modules = (Get-ToolsetContent).powershellModules.name

    $psModules = Get-Module -Name $modules -ListAvailable | Sort-Object Name | Group-Object Name
    $psModules | ForEach-Object {
        $moduleName = $_.Name
        $moduleVersions = ($_.group.Version | Sort-Object -Unique) -join '<br>'

        [PSCustomObject]@{
            Module = $moduleName
            Version = $moduleVersions
        }
    }
}

function Get-DotNetCoreSdkVersions {
    $unsortedDotNetCoreSdkVersion = dotnet --list-sdks list | ForEach-Object { $_ | Take-OutputPart -Part 0 }
    $dotNetCoreSdkVersion = $unsortedDotNetCoreSdkVersion -join " "
    return $dotNetCoreSdkVersion
}

function Get-DotnetTools {
    $env:PATH = "/etc/skel/.dotnet/tools:$($env:PATH)"

    $dotnetTools = (Get-ToolsetContent).dotnet.tools

    $toolsList = @()

    ForEach ($dotnetTool in $dotnetTools) {
        $toolsList += $dotnetTool.name + " " + (Invoke-Expression $dotnetTool.getversion)
    }

    return $toolsList
}

function Get-CachedDockerImages {
    $toolsetJson = Get-ToolsetContent
    $images = $toolsetJson.docker.images
    return $images
}

function Get-CachedDockerImagesTableData {
    $allImages = sudo docker images --digests --format "*{{.Repository}}:{{.Tag}}|{{.Digest}} |{{.CreatedAt}}"
    $allImages.Split("*") | Where-Object { $_ } | ForEach-Object {
        $parts = $_.Split("|")
        [PSCustomObject] @{
            "Repository:Tag" = $parts[0]
            "Digest" = $parts[1]
            "Created" = $parts[2].split(' ')[0]
        }
    } | Sort-Object -Property "Repository:Tag"
}

function Get-AptPackages {
    $apt = (Get-ToolsetContent).Apt
    $output = @()
    ForEach ($pkg in ($apt.common_packages + $apt.cmd_packages)) {
        $version = $(dpkg-query -W -f '${Version}' $pkg)
        if ($Null -eq $version) {
            $version = $(dpkg-query -W -f '${Version}' "$pkg*")
        }
        
        $version = $version -replace '~','\~'

        $output += [PSCustomObject] @{
            Name    = $pkg
            Version = $version
        }
    }
    return ($output | Sort-Object Name)
}

function Get-PipxVersion {
    $result = (Get-CommandResult "pipx --version").Output
    $result -match "(?<version>\d+\.\d+\.\d+\.?\d*)" | Out-Null
    $pipxVersion = $Matches.Version
    return "Pipx $pipxVersion"
}

function Build-PackageManagementEnvironmentTable {
    return @(
        @{
            "Name" = "VCPKG_INSTALLATION_ROOT"
            "Value" = $env:VCPKG_INSTALLATION_ROOT
        }
    ) | ForEach-Object {
        [PSCustomObject] @{
            "Name" = $_.Name
            "Value" = $_.Value
        }
    }
}
