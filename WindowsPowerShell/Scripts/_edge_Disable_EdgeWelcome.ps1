# https://gist.github.com/likamrat/f5f8fc13e64b2e3dbe737ef04dadb80d
# Disable Microsoft Edge first-run Welcome screen
# 
# Set variables to indicate value and key to set
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name         = 'HideFirstRunExperience'
$Value        = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}  
# Now set the value
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force