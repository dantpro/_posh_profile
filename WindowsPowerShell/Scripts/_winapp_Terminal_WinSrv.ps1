# https://gist.github.com/likamrat/726974f4715d164a4013f7cab2183e3c
# Install Windows Terminal on Windows Server
#
Write-Information "This script needs be run on Windows Server 2019 or 2022"
If ($PSVersionTable.PSVersion.Major -ge 7){ Write-Error "This script needs be run by version of PowerShell prior to 7.0" }

# Define environment variables
$downloadDir = "C:\WinTerminal"
$gitRepo = "microsoft/terminal"
$filenamePattern = "*.msixbundle"
$framworkPkgUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
$framworkPkgPath = "$downloadDir\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$msiPath = "$downloadDir\Microsoft.WindowsTerminal.msixbundle"
$releasesUri = "https://api.github.com/repos/$gitRepo/releases/latest"

#$downloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $filenamePattern ).browser_download_url | Select-Object -SkipLast 1
$downloadUri = ((Invoke-RestMethod -Method GET -Uri $releasesUri).assets | Where-Object name -like $filenamePattern ).browser_download_url

# Download C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release msixbundle
Invoke-WebRequest -Uri $framworkPkgUrl -OutFile ( New-Item -Path $framworkPkgPath -Force )
Invoke-WebRequest -Uri $downloadUri -OutFile ( New-Item -Path $msiPath -Force )

# Install C++ Runtime framework packages for Desktop Bridge and Windows Terminal latest release
Add-AppxPackage -Path $framworkPkgPath
Add-AppxPackage -Path $msiPath

# Cleanup
Remove-Item $downloadDir -Recurse -Force
