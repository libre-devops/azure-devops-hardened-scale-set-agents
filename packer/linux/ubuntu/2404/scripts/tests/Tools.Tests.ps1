Describe "azcopy" {
    It "azcopy" {
        "azcopy --version" | Should -ReturnZeroExitCode
    }
}

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

    It "git-lfs" {
        "git-lfs --version" | Should -ReturnZeroExitCode
    }

    It "git-ftp" {
        "git-ftp --version" | Should -ReturnZeroExitCode
    }

    It "hub-cli" {
        "hub --version" | Should -ReturnZeroExitCode
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
    $testCases = @("podman", "buildah", "skopeo", "podman-docker) | ForEach-Object { @{ContainerCommand = $_} }

    It "<ContainerCommand>" -TestCases $testCases {
        param (
            [string] $ContainerCommand
        )

        "$ContainerCommand -v" | Should -ReturnZeroExitCode
    }
}

Describe "Python" {
    $testCases = @("python", "pip", "python3", "pip3") | ForEach-Object { @{PythonCommand = $_} }

    It "<PythonCommand>" -TestCases $testCases {
        param (
            [string] $PythonCommand
        )

        "$PythonCommand --version" | Should -ReturnZeroExitCode
    }   
}

Describe "yq" {
    It "yq" {
        "yq -V" | Should -ReturnZeroExitCode
    }
}
