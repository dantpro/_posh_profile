# Prompt ######
#<#
function global:prompt {
    $host.ui.RawUI.WindowTitle = $(get-location)	

    Write-Host -Object "[" -NoNewline
    Write-Host -Object "PoSh" -NoNewline -ForegroundColor Cyan
 
    return "] "

}
##>

# Aliases #####
#
New-Alias gh Get-Help
New-Alias ga Get-Alias
New-Alias gcmd Get-Command

# Functions #####
#
# grep #####
#
Function grep {   
    $input | Out-String -Stream | Select-String $args 
}

# touch #####
#
function touch {
<#
.SYNOPSIS
Emulates the Unix touch utility's core functionality.
#>
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]] $Path
    )

    # For all paths of / resolving to existing files, update the last-write timestamp to now.
    #
    if ($existingFiles = (Get-ChildItem -File $Path -ErrorAction SilentlyContinue -ErrorVariable errs)) {
        Write-Verbose "Updating last-write and last-access timestamps to now: $existingFiles"
        $now = Get-Date
        $existingFiles.ForEach('LastWriteTime', $now)
        $existingFiles.ForEach('LastAccessTime', $now)
    }

    # For all non-existing paths, create empty files.
    #
    if ($nonExistingPaths = $errs.TargetObject) {
        Write-Verbose "Creatng empty file(s): $nonExistingPaths"
        $null = New-Item $nonExistingPaths
    }

}
