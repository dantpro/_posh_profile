# https://itpro.outsidesys.com/2016/03/20/lab-add-a-member-server-with-powershell/

# Define the IPv4 Addressing
$IPv4Address = "10.10.99.50"
$IPv4Prefix = "24"
$IPv4GW = "10.10.99.1"
$IPv4DNS = "10.10.100.25"

# Get the Network Adapter's Prefix 
$ipIF = (Get-NetAdapter).ifIndex 

# Turn off IPv6 Random & Temporary IP Assignments 
Set-NetIPv6Protocol -RandomizeIdentifiers Disabled 
Set-NetIPv6Protocol -UseTemporaryAddresses Disabled 

# Turn off IPv6 Transition Technologies 
Set-Net6to4Configuration -State Disabled 
Set-NetIsatapConfiguration -State Disabled 
Set-NetTeredoConfiguration -Type Disabled 

# Add IPv4 Address, Gateway, and DNS 
New-NetIPAddress -InterfaceIndex $ipIF -IPAddress $IPv4Address -PrefixLength $IPv4Prefix -DefaultGateway $IPv4GW 
Set-DNSClientServerAddress –interfaceIndex $ipIF –ServerAddresses $IPv4DNS 
 

# Rename, Join, and Reboot
# Define the Computer Name, Domain Name, and OU Path
$computerName = "srv1"
$domainName = "contoso.com"
$OUpath = "OU=Servers,OU=Resources,DC=contoso,DC=com"

# Get Domain Admin Credentials
$Credentials = Get-Credential "domain.admin@contoso.com"

# Add the Computer to the Domain
Add-Computer -Credential $Credentials -NewName $computerName -DomainName $domainName -OUPath $OUpath -Restart -Force

