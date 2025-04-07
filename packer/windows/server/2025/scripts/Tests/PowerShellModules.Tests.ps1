Describe "PowerShellModules" {
    $modules = (Get-ToolsetContent).powershellModules
    $withoutVersionsModules = $modules | Where-Object { -not$_.versions } | ForEach-Object {
        @{ moduleName = $_.name }
    }

    $withVersionsModules = $modules | Where-Object { $_.versions } | ForEach-Object {
        $moduleName = $_.name
        $_.versions | ForEach-Object {
            @{ moduleName = $moduleName; expectedVersion = $_ }
        }
    }

    It "<moduleName> is installed" -TestCases $withoutVersionsModules {
        param($moduleName)
        if ($moduleName -eq "Az" -or "AzureAD" )
        {
            # Use Get-InstalledModule for the Az module to check if it's installed
            { Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue } | Should -Not -Throw
            Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        else
        {
            # Use Get-Module for other modules
            Get-Module -Name $moduleName -ListAvailable | Should -Not -BeNullOrEmpty
        }
    }

    if ($withVersionsModules)
    {
        It "<moduleName> with <expectedVersion> is installed" -TestCases $withVersionsModules {
            param($moduleName, $expectedVersion)
            if ($moduleName -eq "Az")
            {
                # Check version for Az module using Get-InstalledModule
                $installed = Get-InstalledModule -Name $moduleName -RequiredVersion $expectedVersion -ErrorAction SilentlyContinue
                $installed.Version.ToString() | Should -BeExactly $expectedVersion
            }
            else
            {
                # Check version for other modules using Get-Module
                $version = (Get-Module -Name $moduleName -ListAvailable).Version
                $version.ToString() | Should -BeExactly $expectedVersion
            }
        }
    }
}
