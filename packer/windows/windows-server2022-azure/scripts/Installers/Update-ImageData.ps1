$os = Get-CimInstance -ClassName Win32_OperatingSystem
$caption = $os.Caption
$osName = $caption.Substring(0, $caption.LastIndexOf(" "))
$osEdition = $caption.Substring($caption.LastIndexOf(" ")+1)
$osVersion = $os.Version
$imageVersion = $env:IMAGE_VERSION
$imageDataFile = $env:IMAGEDATA_FILE

$json = @"
[
  {
    "group": "Operating System",
    "detail": "${osName}\n${osVersion}\n${osEdition}"
  },
  {
    "group": "Runner Image",
    "detail": "Image: ${imageLabel}\nVersion: ${imageVersion}\nIncluded Software: ${softwareUrl}\nImage Release: ${releaseUrl}"
  }
]
"@

$json | Out-File -FilePath $imageDataFile


# Set static env vars
setx ImageVersion $env:IMAGE_VERSION /m
setx ImageOS $env:IMAGE_OS /m
setx AGENT_TOOLSDIRECTORY $env:AGENT_TOOLSDIRECTORY /m
