$pythonVersions = (Get-ToolsetContent).python.versions

foreach ($version in $pythonVersions)
{
    if ($version -eq "latest")
    {
        $latestPython = pyenv install --list | Where-Object { $_ -match "^\s*[0-9]+\.[0-9]+\.[0-9]+$" } | Select-Object -Last 1
        pyenv install $latestPython
        pyenv global $latestPython
    }
    else
    {
        pyenv install $version
    }
}
Import-Module Pester
Invoke-PesterTests -TestFile "PyenvVersions"
