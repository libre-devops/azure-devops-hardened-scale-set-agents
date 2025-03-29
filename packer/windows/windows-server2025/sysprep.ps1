Write-Output '>>> Waiting for GA to start ...'
while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }

# Write-Output '>>> Waiting for GA Service (WindowsAzureTelemetryService) to start ...'
# while ((Get-Service WindowsAzureTelemetryService).Status -ne 'Running') { Start-Sleep -s 5 }

# Write-Output '>>> Waiting for GA Service (WindowsAzureGuestAgent) to start ...'
# while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }

Write-Output '>>> Sysprepping VM ...'
if( Test-Path $Env:SystemRoot\system32\Sysprep\unattend.xml ) { Remove-Item $Env:SystemRoot\system32\Sysprep\unattend.xml -Force }
& $Env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /quit

while($true) {
    $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState;
    if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  }
    else { Write-Output $imageState.ImageState; break }
}

Write-Output '>>> Sysprep complete ...'
