<#
    .SYNOPSIS
    Export-ADUsers.ps1

    .DESCRIPTION
    Export Active Directory users to CSV file.

    .LINK
    alitajran.com/export-ad-users-to-csv-powershell

    .NOTES
    Written by: ALI TAJRAN
    Website:    alitajran.com
    LinkedIn:   linkedin.com/in/alitajran

    .CHANGELOG
    V1.00, 05/24/2021 - Initial version
    V1.10, 04/01/2023 - Added progress bar, user created date, and OU info
    V1.20, 05/19/2023 - Added function for OU path extraction
#>

# https://www.alitajran.com/export-ad-users-to-csv-powershell/

# Split path
$Path = Split-Path -Parent "C:\scripts\*.*"

# Create variable for the date stamp in log file
$LogDate = Get-Date -f yyyyMMddhhmm

# Define CSV and log file location variables
# They have to be on the same location as the script
$Csvfile = $Path + "\AllADUsers_$LogDate.csv"

# Import Active Directory module
Import-Module ActiveDirectory

# Function to extract OU from DistinguishedName
function Get-OUFromDistinguishedName {
    param(
        [string]$DistinguishedName
    )

    $ouf = ($DistinguishedName -split ',', 2)[1]
    if (-not ($ouf.StartsWith('OU') -or $ouf.StartsWith('CN'))) {
        $ou = ($ouf -split ',', 2)[1]
    }
    else {
        $ou = $ouf
    }
    return $ou
}

# Set distinguishedName as searchbase, you can use one OU or multiple OUs
# Or use the root domain like DC=exoip,DC=local
$DNs = @(
    "OU=Sales,OU=Users,OU=Company,DC=exoip,DC=local",
    "OU=IT,OU=Users,OU=Company,DC=exoip,DC=local",
    "OU=Finance,OU=Users,OU=Company,DC=exoip,DC=local"
)

# Initialize a List to store the data
$Report = [System.Collections.Generic.List[Object]]::new()

# Collect all users from all OUs
$AllUsers = foreach ($DN in $DNs) {
    Get-ADUser -SearchBase $DN -Filter * -Properties *
}

# Loop through each user
$progressCount = 0
foreach ($User in $AllUsers) {
    $progressParams = @{
        Id              = 0
        Activity        = "Retrieving User"
        Status          = "$progressCount of $($AllUsers.Count)"
        PercentComplete = ($progressCount / $AllUsers.Count) * 100
    }
    Write-Progress @progressParams

    # Get manager information
    $Manager = $null
    if ($User.Manager) {
        $Manager = Get-ADUser -Identity $User.Manager -Properties DisplayName, UserPrincipalName -ErrorAction SilentlyContinue
    }

    # Build the report line
    $ReportLine = [PSCustomObject]@{
        "First name"           = $User.GivenName
        "Last name"            = $User.Surname
        "Display name"         = $User.DisplayName
        "User logon name"      = $User.SamAccountName
        "User principal name"  = $User.UserPrincipalName
        "Street"               = $User.StreetAddress
        "City"                 = $User.City
        "State/province"       = $User.State
        "Zip/Postal Code"      = $User.PostalCode
        "Country/region"       = $User.Country
        "Job Title"            = $User.Title
        "Department"           = $User.Department
        "Company"              = $User.Company
        "Manager display name" = if ($Manager) { $Manager.DisplayName } else { $null }
        "Manager UPN"          = if ($Manager) { $Manager.UserPrincipalName } else { $null }
        "OU"                   = Get-OUFromDistinguishedName $User.DistinguishedName
        "Description"          = $User.Description
        "Office"               = $User.Office
        "Telephone number"     = $User.telephoneNumber
        "Other Telephone"      = if ($User.otherTelephone) { $User.otherTelephone -join ";" } else { $null }
        "E-mail"               = $User.Mail
        "Mobile"               = $User.mobile
        "Pager"                = $User.pager
        "Notes"                = $User.info
        "Account status"       = if ($User.Enabled) { 'Enabled' } else { 'Disabled' }
        "User created date"    = $User.WhenCreated
        "Last logon date"      = $User.lastlogondate
    }
    # Add the report line to the List
    $Report.Add($ReportLine)
    $progressCount++
}

# Sort and export CSV
$SortReport = $Report | Sort-Object "Display name"
$SortReport | Export-Csv -Path $Csvfile -NoTypeInformation -Encoding utf8 #-Delimiter ";"