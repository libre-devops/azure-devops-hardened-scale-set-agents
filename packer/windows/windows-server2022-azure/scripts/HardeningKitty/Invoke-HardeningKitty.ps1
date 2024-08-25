Set-Location -Path $Env:HARDENING_KITTY_PATH
Get-ChildItem

Invoke-HardeningKitty -Mode HailMary -Log -Report -FileFindingList ".\lists\$($Env:HARDENING_KITTY_FILES_TO_RUN)"
