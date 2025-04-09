Describe "Azure CLI" {
    It "Azure CLI" {
        "az --version" | Should -ReturnZeroExitCode
    }
}

Describe "GitHub CLI" {
    It "gh cli" {
        "gh --version" | Should -ReturnZeroExitCode
    }

    It "hub is installed" {
        "hub --version" | Should -ReturnZeroExitCode
    }
}