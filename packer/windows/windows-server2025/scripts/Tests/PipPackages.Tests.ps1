Describe "PipPackages" {
    $pipToolset = (Get-ToolsetContent).pip
    $testCases = $pipToolset | ForEach-Object { @{package = $_.package; cmd = $_.cmd} }
    It "<package>" -TestCases $testCases {
        "$cmd" | Should -ReturnZeroExitCode
    }
}