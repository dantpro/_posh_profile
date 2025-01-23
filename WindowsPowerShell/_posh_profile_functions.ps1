#
# Functions 
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

# Update Help #####
#
Function Upd-Hlp {
    $error.Clear()
    Update-Help -Module * -Force -ea 0
    For ($i = 0 ; $i -lt $error.Count ; $i ++) { 
        "`nerror $i" ; $error[$i].exception
    }
}

# Get Environments
#
Function Get-EnvPath {$env:path -split ";" | Sort-Object}
Function Get-EnvPsmPath {$env:PSModulePath -split ";" | Sort-Object}
Function Get-EnvAll {Get-ChildItem env:* | Sort-Object -Property Name}

# Create easy to remember short hand for editing this file
#
Function Edit-Profile {ise $profile}
