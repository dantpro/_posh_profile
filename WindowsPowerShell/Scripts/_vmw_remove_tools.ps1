# https://gist.github.com/broestls/f872872a00acee2fca02017160840624
#
#

# This script will manually rip out all VMware Tools registry entries and files for Windows 2008-2019
# Tested for 2019, 2016, and probably works on 2012 R2 after the 2016 fixes.

# This function pulls out the common ID used for most of the VMware registry entries along with the ID
# associated with the MSI for VMware Tools.
function Get-VMwareToolsInstallerID {
    foreach ($item in $(Get-ChildItem Registry::HKEY_CLASSES_ROOT\Installer\Products)) {
        If ($item.GetValue('ProductName') -eq 'VMware Tools') {
            return @{
                reg_id = $item.PSChildName;
                msi_id = [Regex]::Match($item.GetValue('ProductIcon'), '(?<={)(.*?)(?=})') | Select-Object -ExpandProperty Value
            }
        }
    }
}

$vmware_tools_ids = Get-VMwareToolsInstallerID

# Targets we can hit with the common registry ID from $vmware_tools_ids.reg_id
$reg_targets = @(
    "Registry::HKEY_CLASSES_ROOT\Installer\Features\",
    "Registry::HKEY_CLASSES_ROOT\Installer\Products\",
    "HKLM:\SOFTWARE\Classes\Installer\Features\",
    "HKLM:\SOFTWARE\Classes\Installer\Products\",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\"
)

$VMware_Tools_Directory = "C:\Program Files\VMware"
$VMware_Common_Directory = "C:\Program Files\Common Files\VMware"

# Create an empty array to hold all the uninstallation targets and compose the entries into the target array
$targets = @()

If ($vmware_tools_ids) {
    foreach ($item in $reg_targets) {
        $targets += $item + $vmware_tools_ids.reg_id
    }
    # Add the MSI installer ID regkey
    $targets += "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{$($vmware_tools_ids.msi_id)}"
}

# This is a bit of a shotgun approach, but if we are at a version less than 2016, add the Uninstaller entries we don't
# try to automatically determine.
If ([Environment]::OSVersion.Version.Major -lt 10) {
    $targets += "HKCR:\CLSID\{D86ADE52-C4D9-4B98-AA0D-9B0C7F1EBBC8}"
    $targets += "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{9709436B-5A41-4946-8BE7-2AA433CAF108}"
    $targets += "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{FE2F6A2C-196E-4210-9C04-2B1BC21F07EF}"
}

# Add the VMware, Inc regkey
If (Test-Path "HKLM:\SOFTWARE\VMware, Inc.") {
    $targets += "HKLM:\SOFTWARE\VMware, Inc."
}

# Add the VMware Tools directory
If(Test-Path $VMware_Tools_Directory) {
    $targets += $VMware_Tools_Directory
}

# Thanks to @Gadgetgeek2000 for pointing out that the script leaves some 500mb of extra artifacts on disk.
# This blob removes those.
If(Test-Path $VMware_Common_Directory) {
    $targets += $VMware_Common_Directory
}

# Create a list of services to stop and remove
$services = Get-Service -DisplayName "VMware*"
$services += Get-Service -DisplayName "GISvc"

# Warn the user about what is about to happen
# Takes only y for an answer, bails otherwise.
Write-Host "The following registry keys, filesystem folders, and services will be deleted:"
If (!$targets -and !$services ) {
    Write-Host "Nothing to do!"
}
Else {
    $targets
    $services
    $user_confirmed = Read-Host "Continue (y/n)"
    If ($user_confirmed -eq "y") {

    # Stop all running VMware Services
    $services | Stop-Service -Confirm:$false

    # Cover for Remove-Service not existing in PowerShell versions < 6.0
    If (Get-Command Remove-Service -errorAction SilentlyContinue) {
        $services | Remove-Service -Confirm:$false
    }
    Else {
        foreach ($s in $services) {
            sc.exe DELETE $($s.Name)
        }
    }

    # Remove all the files that are listed in $targets
    foreach ($item in $targets) {
        If(Test-Path $item) {
            Remove-Item -Path $item -Recurse
        }
    }
    Write-Host "Done. Reboot to complete removal."
    }
    Else {
        Write-Host "Failed to get user confirmation"
    }
}

