Describe "azcopy" {
    It "azcopy" {
        "azcopy --version" | Should -ReturnZeroExitCode
    }

    It "azcopy10 link exists" {
        "azcopy10 --version" | Should -ReturnZeroExitCode
    }
}

Describe "Docker" {
    It "docker" {
        "docker --version" | Should -ReturnZeroExitCode
    }

    It "docker buildx" {
        "docker buildx" | Should -ReturnZeroExitCode
    }

    It "docker compose v2" {
        "docker compose" | Should -ReturnZeroExitCode
    }

    It "docker-credential-ecr-login" {
        "docker-credential-ecr-login -v" | Should -ReturnZeroExitCode
    }

    Context "docker images" {
        $testCases = (Get-ToolsetContent).docker.images | ForEach-Object { @{ ImageName = $_ } }

        It "<ImageName>" -TestCases $testCases {
           sudo docker images "$ImageName" --format "{{.Repository}}" | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Docker-compose v1" {
    It "docker-compose" {
        "docker-compose --version"| Should -ReturnZeroExitCode
    }
}

Describe "Ansible" {
    It "Ansible" {
        "ansible --version" | Should -ReturnZeroExitCode
    }
}

Describe "Checkov" {
    It "Checkov" {
        "checkov --version" | Should -ReturnZeroExitCode
    }
}

Describe "Terraform-Compliance" {
    It "Terraform-Compliance" {
        "terraform-compliance --version" | Should -ReturnZeroExitCode
    }
}

# TFenv is used to install terraform and this will test a version is installed
Describe "Tfenv" {
    It "tfenv" {
        "tfenv list" | Should -ReturnZeroExitCode
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

Describe "Kubernetes tools" {
    It "kind" {
        "kind --version" | Should -ReturnZeroExitCode
    }

    It "kubectl" {
        "kubectl version" | Should -MatchCommandOutput "Client Version: version.Info"
    }

    It "helm" {
        "helm version" | Should -ReturnZeroExitCode
    }

    It "minikube" {
        "minikube version" | Should -ReturnZeroExitCode
    }

    It "kustomize" {
        "kustomize version" | Should -ReturnZeroExitCode
    }
}

Describe "Packer" {
    It "packer" {
        "packer --version" | Should -ReturnZeroExitCode
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
