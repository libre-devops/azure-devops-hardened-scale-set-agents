Describe "DiskSpace" {
    It "The image has enough disk space"{
        $availableSpaceMB =  [math]::Round((Get-PSDrive -Name C).Free / 1MB)
        $minimumFreeSpaceMB = 18 * 1024

        $availableSpaceMB | Should -BeGreaterThan $minimumFreeSpaceMB
    }
}

Describe "DynamicPorts" {
    It "Test TCP dynamicport start=49152 num=16384" {
        $tcpPorts = Get-NetTCPSetting | Where-Object {$_.SettingName -ne "Automatic"} | Where-Object {
            $_.DynamicPortRangeStartPort -ne 49152 -or $_.DynamicPortRangeNumberOfPorts -ne 16384
        }

        $tcpPorts | Should -BeNullOrEmpty
    }

    It "Test UDP dynamicport start=49152 num=16384" {
        $udpPorts = Get-NetUDPSetting | Where-Object {
            $_.DynamicPortRangeStartPort -ne 49152 -or $_.DynamicPortRangeNumberOfPorts -ne 16384
        }

        $udpPorts | Should -BeNullOrEmpty
    }
}

Describe "Test Signed Drivers" {
    It "bcdedit testsigning should be Yes"{
        "$(bcdedit)" | Should -Match "testsigning\s+Yes"
    }
}

Describe "Windows Updates" {
    It "WindowsUpdateDone.txt should exist" {
        "$env:windir\WindowsUpdateDone.txt" | Should -Exist
    }

    $testCases = Get-WindowsUpdatesHistory | Sort-Object Title | ForEach-Object {
        @{
            Title = $_.Title
            Status = $_.Status
        }
    }

    It "<Title>" -TestCases $testCases {
        $expect = "Successful"
        if ( $Title -match "Microsoft Defender Antivirus" ) {
            $expect = "Successful", "Failure", "InProgress"
        }

        $Status | Should -BeIn $expect
    }
}
