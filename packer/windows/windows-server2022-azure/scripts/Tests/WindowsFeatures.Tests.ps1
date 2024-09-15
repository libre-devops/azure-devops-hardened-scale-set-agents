Describe "WindowsFeatures" {
    $windowsFeatures = (Get-ToolsetContent).windowsFeatures
    $testCases = $windowsFeatures | ForEach-Object { @{ Name = $_.name; OptionalFeature = $_.optionalFeature } }

    It "Windows Feature <Name> is installed" -TestCases $testCases {
        if ($OptionalFeature) {
            (Get-WindowsOptionalFeature -Online -FeatureName $Name).State | Should -Be "Enabled"
        } else {
            (Get-WindowsFeature -Name $Name).InstallState | Should -Be "Installed"
        }
    }

    it "Check WSL is on path" {
        (Get-Command -Name 'wsl') | Should -BeTrue
    }

    it "Check WLAN service is stopped" {
        (Get-Service -Name wlansvc).Status | Should -Be "Stopped"
    }
}

Describe "Windows Updates" {
    It "WindowsUpdateDone.txt should exist" {
        "$env:windir\WindowsUpdateDone.txt" | Should -Exist
    }

    $testCases = Get-WindowsUpdateStates | Sort-Object Title | ForEach-Object {
        @{
            Title = $_.Title
            State = $_.State
        }
    }

    It "<Title>" -TestCases $testCases {
        $expect = "Installed"
        if ( $Title -match "Microsoft Defender Antivirus" ) {
            $expect = "Installed", "Failed", "Running"
        }

        $State | Should -BeIn $expect
    }
}
