$ADRoot = (Get-ADDomain).DistinguishedName ; (Get-ADOrganizationalUnit "ou=domain controllers,$ADRoot" -Properties *).Created
