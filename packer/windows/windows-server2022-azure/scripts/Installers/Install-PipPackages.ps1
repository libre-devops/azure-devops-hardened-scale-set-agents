################################################################################
##  File:  Install-PipPackages.ps1
##  Desc:  Install pip packages
################################################################################

Write-Host "Installing pip..."
$env:PIPX_BIN_DIR = "${env:ProgramFiles(x86)}\pipx_bin"
$env:PIPX_HOME = "${env:ProgramFiles(x86)}\pipx"

pip install pipx
if ($LASTEXITCODE -ne 0) {
    throw "pipx installation failed with exit code $LASTEXITCODE"
}

Add-MachinePathItem "${env:PIPX_BIN_DIR}"
[Environment]::SetEnvironmentVariable("PIPX_BIN_DIR", $env:PIPX_BIN_DIR, "Machine")
[Environment]::SetEnvironmentVariable("PIPX_HOME", $env:PIPX_HOME, "Machine")

Invoke-PesterTests -TestFile "Tools" -TestName "Pipx"

Write-Host "Installing pip packages..."

$pipToolset = (Get-ToolsetContent).pip
foreach ($tool in $pipToolset) {
    if ($tool.python) {
        $pythonPath = (Get-Item -Path "${env:AGENT_TOOLSDIRECTORY}\Python\${tool.python}.*\x64\python-${tool.python}*").FullName
        Write-Host "Install ${tool.package} into python ${tool.python}"
        pip3 install $tool.package
    } else {
        Write-Host "Install ${tool.package} into default python"
        pip3 install $tool.package
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Package ${tool.package} installation failed with exit code $LASTEXITCODE"
    }
}

Invoke-PesterTests -TestFile "PipPackages"