Describe "Docker" {
    It "docker is installed" {
        "docker --version" | Should -ReturnZeroExitCode
    }

    It "docker service is up" {
        "docker images" | Should -ReturnZeroExitCode
    }

    It "docker symlink" {
        "C:\Windows\SysWOW64\docker.exe ps" | Should -ReturnZeroExitCode
    }
}

Describe "DockerCompose" {
    It "docker compose v2" {
        "docker compose version" | Should -ReturnZeroExitCode
    }
}

Describe "DockerWinCred" {
    It "docker-wincred" {
        "docker-credential-wincred version" | Should -ReturnZeroExitCode
    }
}