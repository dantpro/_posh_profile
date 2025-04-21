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

# Create password
#
# https://stackoverflow.com/questions/37256154/powershell-password-generator-how-to-always-include-number-in-string

function New-Password {
<#
.SYNOPSIS
    Creates a cryptographically secure password

.DESCRIPTION
    Creates a cryptographically secure password

    The dotnet class [RandomNumberGenerator] is used
    to create cryptographically random values which
    are converted to numbers and used to index each
    character set.

    Minimum requires characters types is implemented
    by generating those values up front, generating
    any remaining characters with the full character set
    then shuffling everything together.

    This cmdlet is compatible with both Powershell Desktop
    and Core. When using Powershell Core, a safer shuffler
    cmdlet is used.

.NOTES
    Thanks to
    * CodesInChaos - Core functionality from his CSharp version (https://stackoverflow.com/a/19068116/5339918)
    * Jamesdlin - Minimum char shuffle idea (https://stackoverflow.com/a/74323305/5339918)
    * Shane - Json safe flag idea (https://stackoverflow.com/a/73316960/5339918)

.EXAMPLE
    Basic usage

    New-Password

.EXAMPLE
    Specify password length and exclude Numbers/Symbols from password

    New-Password -Length 64 -NumberCharset @() -SymbolCharset @()

.EXAMPLE
    Require 2 of each character set in final password

    New-Password -MinimumUpper 2 -MinimumLower 2 -MinimumNumber 2 -MinimumSymbol 2
#>

    [CmdletBinding()]
    param(
        [ValidateRange(1, [uint32]::MaxValue)]
        
        #-- [uint32] $Length = 32,
        [uint32] $Length = 16,

        [uint32] $MinimumUpper = 5,
        [uint32] $MinimumLower = 5,
        [uint32] $MinimumNumber = 5,
        [uint32] $MinimumSymbol = 1,

        [char[]] $UpperCharSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        [char[]] $LowerCharSet = 'abcedefghijklmnopqrstuvwxyz',
        [char[]] $NumberCharSet = '0123456789',
        
        #-- [char[]] $SymbolCharSet = '!@#$%^&*()[]{},.:`~_-=+',  # Excludes problematic characters like ;'"/\,
        [char[]] $SymbolCharSet = '-',
        
        [switch] $JsonSafe
    )

    #============
    # PRE CREATE
    #============

    if ($JsonSafe) {
        $ProblemCharacters = @(';', "'", '"', '/', '\', ',', '`', '&', '+')
        [char[]] $SymbolCharSet = $SymbolCharSet | Where-Object { $_ -notin $ProblemCharacters }
    }

    # Parameter validation
    switch ($True) {
        { $MinimumUpper -and -not $UpperCharSet } { throw 'Cannot require uppercase without a uppercase charset' }
        { $MinimumLower -and -not $UpperCharSet } { throw 'Cannot require lowercase without a lowercase charset' }
        { $MinimumNumber -and -not $UpperCharSet } { throw 'Cannot require numbers without a numbers charset' }
        { $MinimumSymbol -and -not $SymbolCharSet } { throw 'Cannot require symbols without a symbol charset' }
    }

    $TotalMinimum = $MinimumUpper + $MinimumLower + $MinimumNumber + $MinimumSymbol
    if ($TotalMinimum -gt $Length) {
        throw "Total required characters ($TotalMinimum) exceeds password length ($Length)"
    }

    $FullCharacterSet = $UpperCharSet + $LowerCharSet + $NumberCharSet + $SymbolCharSet

    #=========
    # CREATE
    #=========

    $CharArray = [char[]]::new($Length)
    $Bytes = [Byte[]]::new($Length * 8)  # 8 bytes = 1 uint64
    $RNG = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $RNG.GetBytes($Bytes)  # Populate bytes with random numbers

    for ($i = 0; $i -lt $Length; $i++) {

        # Convert the next 8 bytes to a uint64 value
        [uint64] $Value = [BitConverter]::ToUInt64($Bytes, $i * 8)

        if ($MinimumUpper - $UpperSatisfied) {
            $CharArray[$i] = $UpperCharSet[$Value % [uint64] $UpperCharSet.Length]
            $UpperSatisfied++
            continue
        }

        if ($MinimumLower - $LowerSatisfied) {
            $CharArray[$i] = $LowerCharSet[$Value % [uint64] $LowerCharSet.Length]
            $LowerSatisfied++
            continue
        }

        if ($MinimumNumber - $NumberSatisfied) {
            $CharArray[$i] = $NumberCharSet[$Value % [uint64] $NumberCharSet.Length]
            $NumberSatisfied++
            continue
        }


        if ($MinimumSymbol - $SymbolSatisfied) {
            $CharArray[$i] = $SymbolCharSet[$Value % [uint64] $SymbolCharSet.Length]
            $SymbolSatisfied++
            continue
        }

        $CharArray[$i] = $FullCharacterSet[$Value % [uint64] $FullCharacterSet.Length]
    }
   
    if ($TotalMinimum -gt 0) {
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $CharArray = $CharArray | Get-SecureRandom -Shuffle
        } else {
            # If `-SetSeed` is used, this would always produce the same result
            $CharArray = $CharArray | Get-Random -Count $Length
        }
    }

    return [String]::new($CharArray)
}
####

# LDAP Whoami #####
#
function Invoke-LDAPWhoami
{
    Add-Type -AssemblyName System.DirectoryServices.Protocols -ErrorAction Stop
    
    $connect = new-object System.DirectoryServices.Protocols.LdapConnection("$($env:userdnsdomain)")
    $request = new-object System.DirectoryServices.Protocols.ExtendedRequest('1.3.6.1.4.1.4203.1.11.3')
    
    $result = ([System.Text.Encoding]::ASCII.GetString($connect.SendRequest($request).ResponseValue)).split(":")[1]
    
    Write-Host "Current context is: $result"
}
####

# Get-ScriptDirectory ##### 
#
# https://www.red-gate.com/simple-talk/development/dotnet-development/further-down-the-rabbit-hole-powershell-modules-and-encapsulation

function Get-ScriptDirectory
{
    Split-Path $script:MyInvocation.MyCommand.Path
}
###
