Set-Location -Path "C:/image/HardeningKitty"

Invoke-HardeningKitty -Mode HailMary -Log -Report -FileFindingList ".\scripts\lists\$($Env:HARDENING_KITTY_FILES_TO_RUN)"
