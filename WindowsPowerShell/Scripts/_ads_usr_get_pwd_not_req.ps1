"---"
<#
Get-ADUser -Filter {Enabled -eq $true} -Properties userAccountControl |
    Where-Object { ($_.userAccountControl -band 0x20) } |
    Select-Object Name, userAccountControl, distinguishedName
#>
"---"
#<#
Get-ADUser -Filter {PasswordNotRequired -eq $true} -Properties PasswordNotRequired, userAccountControl |
    Select-Object Name, PasswordNotRequired, userAccountControl, distinguishedName |
    Sort-Object Name
#>
"---"