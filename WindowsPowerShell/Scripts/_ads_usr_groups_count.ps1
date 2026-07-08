# https://serverfault.com/questions/1062835/get-the-count-of-ad-groups-a-user-is-a-member-of
# https://stackoverflow.com/questions/23552094/how-to-get-all-ad-user-groups-recursively-with-powershell-or-other-tools

(Get-ADUser -SearchScope Base -SearchBase (Get-ADUser <UserName>).DistinguishedName -LDAPFilter '(objectClass=user)' -Properties tokenGroups |
    Select-Object -ExpandProperty tokenGroups |
    Select-Object -ExpandProperty Value |
    %{(Get-ADGroup $_).Name} |
    Sort-Object).Count
