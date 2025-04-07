param (
    [Parameter(Mandatory)][string]
    $OutputDirectory
)

$global:ErrorActionPreference = "Stop"
$global:ErrorView = "NormalView"
Set-StrictMode -Version Latest

Import-Module MarkdownPS
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.CachedTools.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Common.psm1") -DisableNameChecking
Import-Module "$PSScriptRoot/../helpers/SoftwareReport.Helpers.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/../helpers/Common.Helpers.psm1" -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Tools.psm1") -DisableNameChecking

# Restore file owner in user profile
Restore-UserOwner

$markdown = ""

$OSName = Get-OSName
$markdown += New-MDHeader "$OSName" -Level 1

$kernelVersion = Get-KernelVersion
$markdown += New-MDList -Style Unordered -Lines @(
    "$kernelVersion"
    "Image Version: $env:IMAGE_VERSION"
)

$markdown += New-MDHeader "Installed Software" -Level 2
$markdown += New-MDHeader "Language and Runtime" -Level 3

$runtimesList = @(
    (Get-BashVersion),
    (Get-PythonVersion),
    (Get-Python3Version)
)

$markdown += New-MDList -Style Unordered -Lines ($runtimesList | Sort-Object)

$markdown += New-MDHeader "Package Management" -Level 3

$packageManagementList = @(
    (Get-HomebrewVersion),
    (Get-PipxVersion),
    (Get-PipVersion),
    (Get-Pip3Version),
    (Get-VcpkgVersion)
)

$markdown += New-MDList -Style Unordered -Lines ($packageManagementList | Sort-Object)
$markdown += New-MDHeader "Environment variables" -Level 4
$markdown += Build-PackageManagementEnvironmentTable | New-MDTable
$markdown += New-MDNewLine

$markdown += New-MDHeader "Project Management" -Level 3
$projectManagementList = @()

$markdown += New-MDHeader "Tools" -Level 3
$toolsList = @(
    (Get-AnsibleVersion),
    (Get-AptFastVersion),
    (Get-AzCopyVersion),
    (Get-DockerMobyClientVersion),
    (Get-DockerMobyServerVersion),
    (Get-DockerComposeV1Version),
    (Get-DockerComposeV2Version),
    (Get-DockerBuildxVersion),
    (Get-DockerAmazonECRCredHelperVersion),
    (Get-BuildahVersion),
    (Get-PodManVersion),
    (Get-SkopeoVersion),
    (Get-GitVersion),
    (Get-GitLFSVersion),
    (Get-GitFTPVersion),
    (Get-SVNVersion),
    (Get-JqVersion),
    (Get-YqVersion),
    (Get-KindVersion),
    (Get-KubectlVersion),
    (Get-KustomizeVersion),
    (Get-MinikubeVersion),
    (Get-OpensslVersion),
    (Get-PackerVersion),
    (Get-TerraformVersion),
    (Get-YamllintVersion),
    (Get-ZstdVersion)
)

$markdown += New-MDList -Style Unordered -Lines ($toolsList | Sort-Object)

$markdown += New-MDHeader "CLI Tools" -Level 3
$markdown += New-MDList -Style Unordered -Lines (@(
    (Get-AzureCliVersion),
    (Get-AzureDevopsVersion),
    (Get-GitHubCliVersion),
    (Get-HubCliVersion)
    ) | Sort-Object
)

$markdown += New-MDHeader ".NET Core SDK" -Level 3
$markdown += New-MDList -Style Unordered -Lines @(
    (Get-DotNetCoreSdkVersions)
)

$markdown += New-MDHeader ".NET tools" -Level 3
$tools = Get-DotnetTools
$markdown += New-MDList -Lines $tools -Style Unordered

$markdown += New-MDHeader "Databases" -Level 3
$databaseLists = @(
    (Get-SqliteVersion)
)
$markdown += New-MDList -Style Unordered -Lines ( $databaseLists | Sort-Object )

$markdown += New-MDHeader "Cached Tools" -Level 3
$markdown += Build-CachedToolsSection

$markdown += New-MDHeader "Environment variables" -Level 4
$markdown += New-MDNewLine

$markdown += New-MDHeader "PowerShell Tools" -Level 3
$markdown += New-MDList -Lines (Get-PowershellVersion) -Style Unordered

$markdown += New-MDHeader "PowerShell Modules" -Level 4
$markdown += Get-PowerShellModules | New-MDTable
$markdown += New-MDNewLine
$markdown += New-MDHeader "Az PowerShell Modules" -Level 4
$markdown += New-MDList -Style Unordered -Lines @(
    (Get-AzModuleVersions)
)

$markdown += New-MDHeader "Cached Docker images" -Level 3
$markdown += Get-CachedDockerImagesTableData | New-MDTable
$markdown += New-MDNewLine

$markdown += New-MDHeader "Installed apt packages" -Level 3
$markdown += Get-AptPackages | New-MDTable

Test-BlankElement
$markdown | Out-File -FilePath "${OutputDirectory}/Ubuntu-Readme.md"
