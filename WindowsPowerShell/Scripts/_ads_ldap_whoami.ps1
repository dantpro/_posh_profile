function Invoke-LDAPWhoami
{
    Add-Type -AssemblyName System.DirectoryServices.Protocols -ErrorAction Stop
    
    $connect = new-object System.DirectoryServices.Protocols.LdapConnection("$($env:userdnsdomain)")
    $request = new-object System.DirectoryServices.Protocols.ExtendedRequest('1.3.6.1.4.1.4203.1.11.3')
    
    $result = ([System.Text.Encoding]::ASCII.GetString($connect.SendRequest($request).ResponseValue)).split(":")[1]
    
    Write-Host "Current context is: $result"
}
Invoke-LDAPWhoami
