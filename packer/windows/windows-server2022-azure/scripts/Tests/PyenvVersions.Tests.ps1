Describe "PyenvVersions" {
    It "Pyenv Versions are installed" {
        "pyenv global" | Should -ReturnZeroExitCode
    }
}