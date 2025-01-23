#
# PowerShell Core Profile 
# C:\Users\<UserName>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#

# Set Variables #####
#
$MaximumHistoryCount = 4096

$PoshHomePath = $(Split-Path $(Split-Path -Path $Profile)) + "\WindowsPowershell"
$PwshHomePath = $(Split-Path $(Split-Path -Path $Profile)) + "\Powershell"

$PwshStartPath = $(Split-Path $(Split-Path $(Split-Path -Path $Profile)))

#$PoshHomePath = "C:\_home\Documents\WindowsPowerShell"
#$PwshHomePath = "C:\_home\Documents\PowerShell"
#$PwshStartPath = "C:\_home"

# Set Default Location ######
#
Set-Location $PwshStartPath

# Set Path ######
#
$env:Path += ";$PwshHomePath\Scripts;$PoshHomePath\Scripts"

# Modules ######
#
#Import-Module -Name my-module
#
# chocolatey https://ch0.co/tab-completion
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Aliases ######
#
. "$PoshHomePath\_posh_profile_aliases.ps1"
. "$PwshHomePath\_pwsh_profile_aliases.ps1"

# Prompt ######
#
#<#
function global:prompt {
    $host.ui.RawUI.WindowTitle = $(get-location)
    Write-Host -Object "[" -NoNewLine
    Write-Host -Object "PwSh" -NoNewline -ForegroundColor DarkCyan
    return "] "
}
##>

# Functions ######
#
. "$PoshHomePath\_posh_profile_functions.ps1"
. "$PwshHomePath\_pwsh_profile_functions.ps1"

# Misc ######
#
Set-StrictMode -Version 2
<#
1.0
    Prohibits references to uninitialized variables, except for uninitialized variables in strings.
2.0
    Prohibits references to uninitialized variables. This includes uninitialized variables in strings.
    Prohibits references to non-existent properties of an object.
    Prohibits function calls that use the syntax for calling methods.
3.0
    Prohibits references to uninitialized variables. This includes uninitialized variables in strings.
    Prohibits references to non-existent properties of an object.
    Prohibits function calls that use the syntax for calling methods.
    Prohibit out of bounds or unresolvable array indexes.
Latest
Selects the latest version available. The latest version is the most strict.
Use this value to make sure that scripts use the strictest available version, even when new versions are added to PowerShell
#>
#

# PSReadline ######
# 
# Tab completion
Set-PSReadlineKeyHandler -Key Tab -Function Complete
Set-PSReadlineKeyHandler -Chord 'Shift+Tab' -Function MenuComplete

Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 4096
