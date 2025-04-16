Describe "Ansible" {
    It "Ansible" {
        "ansible --version" | Should -ReturnZeroExitCode
    }
}

Describe "Vcpkg" {
    It "vcpkg" {
        "vcpkg version" | Should -ReturnZeroExitCode
    }
}

Describe "Git" {
    It "git" {
        "git --version" | Should -ReturnZeroExitCode
    }
}

Describe "Homebrew" {
    It "homebrew" {
        "brew --version" | Should -ReturnZeroExitCode
    }

    Context "Packages" {
        $testCases = (Get-ToolsetContent).brew | ForEach-Object { @{ ToolName = $_.name } }

        It "<ToolName>" -TestCases $testCases {
           "$ToolName --version" | Should -Not -BeNullOrEmpty
        }
    }
}


Describe "Containers" {
    $testCases = @("podman", "buildah", "skopeo") | ForEach-Object { @{ContainerCommand = $_} }

    It "<ContainerCommand>" -TestCases $testCases {
        param (
            [string] $ContainerCommand
        )

        "$ContainerCommand -v" | Should -ReturnZeroExitCode
    }
}

Describe "yq" {
    It "yq" {
        "yq -V" | Should -ReturnZeroExitCode
    }
}

