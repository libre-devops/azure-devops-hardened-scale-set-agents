$HardeningKittyPath = $Env:HARDENING_KITTY_PATH
$HardeningKittyFilesToRun = $Env:HARDENING_KITTY_FILES_TO_RUN

Set-Location -Path $HardeningKittyFilesToRun

Invoke-HardeningKitty -Mode HailMary -Log -Report -FileFindingList ".\scripts\lists\$HardeningKittyFilesToRun"
