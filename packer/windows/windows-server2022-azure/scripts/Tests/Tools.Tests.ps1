Describe "PowerShell Core" {
    It "pwsh" {
        "pwsh --version" | Should -ReturnZeroExitCode
    }

    It "Execute 2+2 command" {
        pwsh -Command "2+2" | Should -BeExactly 4
    }
}


Describe "Pipx" {
    It "Pipx" {
        "pipx --version" | Should -ReturnZeroExitCode
    }
}

Describe "OpenSSL" {
    It "OpenSSL Version" {
        $OpenSSLVersion = (Get-ToolsetContent).openssl.version
        openssl version | Should -BeLike "* ${OpenSSLVersion}*"
    }

    It "OpenSSL Path" {
        (Get-Command openssl).Source -eq (Join-Path ${env:ProgramFiles} 'OpenSSL\bin\openssl.exe') | Should -Be $true
    }

    It "OpenSSL Full package" {
        Join-Path ${env:ProgramFiles} 'OpenSSL\include' | Should -Exist
    }
}
