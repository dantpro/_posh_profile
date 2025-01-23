# https://www.codykonior.com/2015/11/16/rebuilding-the-log-on-as-a-service-list-after-it-has-been-overwritten-by-group-policy/
#
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Find-LogonAsService {
    [CmdletBinding()]
    param (
    )

    # Defaults from Windows
    $ignoreAccounts = @("LocalSystem", "NT Authority\LocalService", "NT Authority\Local Service", "NT AUTHORITY\NetworkService", "NT AUTHORITY\Network Service")
    $accounts = @("NT SERVICE\ALL SERVICES")

    # Accounts that enabled services should run under
    $accounts += Get-WmiObject -Class Win32_Service | Where { $_.StartMode -ne "Disabled" } | Select-Object -ExpandProperty StartName

    # Special groups created for SQL Server
    $accounts += Get-WmiObject -Class Win32_Account -Namespace "root\cimv2" -Filter "LocalAccount=True" | Where { ($_.SIDType -ne 1 -or !$_.Disabled) -and $_.Name -like "SQLServer*User$*" } | Select-Object -ExpandProperty Name

    # IIS AppPool entities
    try {
        Import-Module WebAdministration
        Get-ChildItem IIS:\AppPools | % {
            $accounts += "IIS APPPOOL\$($_.Name)"
        }
    } catch {
        Write-Warning "** No IIS, or PowerShell not running as Administrator: $_"
    }

    # LocalSystem can be ignored, as it's really NT Authority\SYSTEM, which will
    # be covered by other accounts (like ALL SERVICES).sq,ser
    $accounts | Sort -Unique | Where { $ignoreAccounts -notcontains $_ }
}

function Grant-LogOnAsService {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $User
    )
   
    begin {
        $secedit = "C:\Windows\System32\secedit.exe"
        $gpupdate = "C:\Windows\System32\gpupdate.exe"
        $seceditdb = "$($env:TEMP)\secedit.sdb"

        $oldSids = ""
        $newSids = ""
        $secfileInput = [System.IO.Path]::GetTempFileName()
        $secfileOutput = [System.IO.Path]::GetTempFileName()

        # Get list of currently used SIDs 
        &$secedit /export /cfg $secfileInput | Write-Debug

        # Find the line with existing SIDs if it exists
        if (((Get-Content $secfileInput) -join [Environment]::NewLine) -match "SeServiceLogonRight = (.*)") {
            $oldSids = $Matches[1]
        }
    }

    process {
        # Try to convert each account name to *SID, otherwise just use the account name
        try {
            $userAccount = New-Object System.Security.Principal.NTAccount($User)
            $userTranslated = "*$($userAccount.Translate([System.Security.Principal.SecurityIdentifier]))"
        } catch {
            $userTranslated = $User
        }

        # Only add it to the list if neither SID nor name exist already
        if (!$oldSids.Contains($userTranslated) -and !$oldSids.Contains($User)) {
            $PSCmdlet.ShouldProcess($User) | Out-Null

            if ($newSids) {
                $newSids += ",$userTranslated"
            } else {
                $newSids += $userTranslated
            }
        }
    }

    end {
        # Only update if new SIDs are needed
        if ($newSids) {
            # Concatenate existing SIDs; if there's only one SID it has a newline
            if ($oldSids) {
                $allSids = $oldSids.Trim() + "," + $newSids
            } else {
                $allSids = $newSids
            }

            # Replace the section with the concatenated SID list, or add a new one
            $secFileContent = Get-Content $secfileInput | %{
                if ($oldSids -and $_ -match "SeServiceLogonRight = (.*)") {
                    "SeServiceLogonRight = $allSids"
                } else {
                    $_

                    if ($_ -eq "[Privilege Rights]" -and !$oldSids) {
                        "SeServiceLogonRight = $allSids"
                    }
                }
            }

            Set-Content -Path $secFileOutput -Value $secFileContent -WhatIf:$false

            # If we're really doing it, make the change
            if (!$WhatIfPreference) {
                &$secedit /import /db $seceditdb /cfg $secfileOutput
                &$secedit /configure /db $seceditdb | Write-Debug
                Remove-Item $seceditdb
            }
        } else {
            Write-Verbose "No change"
        }
    
        Remove-Item $secfileInput -WhatIf:$false
        Remove-Item $secfileOutput -WhatIf:$false
    }
}

# ---

Find-LogonAsService
"--"

# Find-LogonAsService | Grant-LogOnAsService -WhatIf
#"--"

# Find-LogonAsService | Grant-LogOnAsService -Verbose

