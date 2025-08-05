"---"
<#
Get-ADUser -Filter {Enabled -eq $true} -Properties userAccountControl |
    Where-Object { ($_.userAccountControl -band 0x20) } |
    Select-Object Name, userAccountControl, distinguishedName
#>
"---"
#<#
Get-ADUser -Filter {PasswordNotRequired -eq $true} -Properties PasswordNotRequired |
    Select-Object Name, PasswordNotRequired, distinguishedName |
    Sort-Object Name
#>
"---"