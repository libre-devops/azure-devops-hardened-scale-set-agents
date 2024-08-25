$HardeningKittyPath = $Env:HARDENING_KITTY_PATH
$HardeningKittyFilesToRun = $Env:HARDENING_KITTY_FILES_TO_RUN

Invoke-HardeningKitty -Mode HailMary -Log -Report -FileFindingList "$HardeningKittyPath\lists\$HardeningKittyFilesToRun"
