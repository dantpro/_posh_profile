#
# https://gist.github.com/cfalta/7d730c15cc30e1d53893efafe248feee
#

<#
.SYNOPSIS
This is a simple script meant to help on your way towards better kerberos encryption (looking at you RC4!) with regards to kerberoasting.
It shows the required encryption types for all kerberoastable user accounts (== user object with spn). Every account that supports somehting else than AES will be marked as unsafe so you can filter for that.
Author: Christoph Falta (@cfalta)
.PARAMETER UnsafeOnly
Shows only accounts that allow unsafe encryption types --> not AES128 or AES256.
.PARAMETER IncludeDisabled
Includes disabled accounts in the result. By default, disabled accounts are NOT included.
#>

[CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)]
        [Switch]
        $IncludeDisabledAccounts,

        [Parameter(Mandatory = $False)]
        [Switch]
        $UnsafeOnly
    )

#Original table here: https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/decrypting-the-selection-of-supported-kerberos-encryption-types/ba-p/1628797
$enctypes_json = @"
[
    {
        "Name":  "RC4_HMAC_MD5",
        "Decimal":  "0",
        "Hex":  "0x0",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_DES_CBC_CRC",
        "Decimal":  "1",
        "Hex":  "0x1",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5",
        "Decimal":  "2",
        "Hex":  "0x2",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-DES_CBC_MD5",
        "Decimal":  "3",
        "Hex":  "0x3",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "RC4",
        "Decimal":  "4",
        "Hex":  "0x4",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-RC4",
        "Decimal":  "5",
        "Hex":  "0x5",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-RC4",
        "Decimal":  "6",
        "Hex":  "0x6",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-DES_CBC_MD5-RC4",
        "Decimal":  "7",
        "Hex":  "0x7",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "AES128",
        "Decimal":  "8",
        "Hex":  "0x8",
        "IsUnsafe":  "False"
    },
    {
        "Name":  "DES_CBC_CRC-AES128",
        "Decimal":  "9",
        "Hex":  "0x9",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-AES128",
        "Decimal":  "10",
        "Hex":  "0xA",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-DES_CBC_MD5-AES128",
        "Decimal":  "11",
        "Hex":  "0xB",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "RC4-AES128",
        "Decimal":  "12",
        "Hex":  "0xC",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-RC4-AES128",
        "Decimal":  "13",
        "Hex":  "0xD",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-RC4-AES128",
        "Decimal":  "14",
        "Hex":  "0xE",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-DES_CBC_MD5-RC4-AES128",
        "Decimal":  "15",
        "Hex":  "0xF",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "AES256",
        "Decimal":  "16",
        "Hex":  "0x10",
        "IsUnsafe":  "False"
    },
    {
        "Name":  "DES_CBC_CRC-AES256",
        "Decimal":  "17",
        "Hex":  "0x11",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-AES256",
        "Decimal":  "18",
        "Hex":  "0x12",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-DES_CBC_MD5-AES256",
        "Decimal":  "19",
        "Hex":  "0x13",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "RC4-AES256",
        "Decimal":  "20",
        "Hex":  "0x14",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-RC4-AES256",
        "Decimal":  "21",
        "Hex":  "0x15",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-RC4-AES256",
        "Decimal":  "22",
        "Hex":  "0x16",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-DES_CBC_MD5-RC4-AES256",
        "Decimal":  "23",
        "Hex":  "0x17",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "AES128-AES256",
        "Decimal":  "24",
        "Hex":  "0x18",
        "IsUnsafe":  "False"
    },
    {
        "Name":  "DES_CBC_CRC-AES128-AES256",
        "Decimal":  "25",
        "Hex":  "0x19",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-AES128-AES256",
        "Decimal":  "26",
        "Hex":  "0x1A",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-DES_CBC_MD5-AES128-AES256",
        "Decimal":  "27",
        "Hex":  "0x1B",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "RC4-AES128-AES256",
        "Decimal":  "28",
        "Hex":  "0x1C",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-RC4-AES128-AES256",
        "Decimal":  "29",
        "Hex":  "0x1D",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_MD5-RC4-AES128-AES256",
        "Decimal":  "30",
        "Hex":  "0x1E",
        "IsUnsafe":  "True"
    },
    {
        "Name":  "DES_CBC_CRC-DES_CBC_MD5-RC4-AES128-AES256",
        "Decimal":  "31",
        "Hex":  "0x1F",
        "IsUnsafe":  "True"
    }
]
"@

$enctypes = $enctypes_json | ConvertFrom-Json

if($IncludeDisabledAccounts)
{
    $Filter = 'serviceprincipalname -like "*"'
}
else{
     $Filter = 'Enabled -eq $true -and serviceprincipalname -like "*"'
}

$user = get-aduser -filter $Filter -properties description,serviceprincipalname,"msds-supportedencryptiontypes"

foreach($u in $user)
{
    if($u.'msds-supportedencryptiontypes')
    {
        $e = $enctypes | ? {$_.decimal -eq $u.'msds-supportedencryptiontypes'}
    }
    else
    {
        #Enctype not set equals RC4
        $e = $enctypes | ? {$_.decimal -eq 0}
    }

    $u | Add-Member -MemberType NoteProperty -Name enctypeName -Value $e.Name -Force
    $u | Add-Member -MemberType NoteProperty -Name enctypeUnsafe -Value $e.IsUnsafe -Force
}

if($UnsafeOnly)
{
    $user | ? {$_.enctypeUnsafe -eq $true} | select Name,samaccountname,description,enctypeName,enctypeUnsafe,serviceprincipalname | ft -AutoSize
}
else
{
    $user | select Name,samaccountname,description,enctypeName,enctypeUnsafe,serviceprincipalname | ft -AutoSize
}
