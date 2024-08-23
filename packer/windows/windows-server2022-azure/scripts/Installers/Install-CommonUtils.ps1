$commonPackages = (Get-ToolsetContent).choco.common_packages

foreach ($package in $commonPackages)
{
    Choco-Install -PackageName $package.name -ArgumentList $package.args
}
Import-Module Pester
Invoke-PesterTests -TestFile "ChocoPackages"
