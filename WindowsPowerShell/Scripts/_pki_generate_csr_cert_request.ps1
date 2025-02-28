# https://gist.github.com/paschott/966f5ae8b1eda5efce874914d95aafd9

# Create new Certificate Request for SQL Server security
# Should be made into a function at some point
# Needs to be able to handle Cluster names/IP addresses

# Set location of the server
#
$Location = "City"
$State = "State"
$OU = "OU"
$Company = "Organization"

$IPv4Address = (Get-NetIPAddress -AddressState Preferred -AddressFamily IPv4 | Where-object IPAddress -ne "127.0.0.1" | Select-Object IPAddress -First 1 -ExpandProperty IPAddress)

# Create C:\CertificateRequest folder if one does not exist
#
$CertFolder = "C:\CertificateRequest"

if (!(Test-Path $CertFolder)) {
    New-Item -Path $CertFolder -Type Directory
}


# Get the FQDN, Computer Name, and IPv4 address
#
$FQDN = [System.Net.DNS]::GetHostByName($Null).HostName
$MachineName = $env:ComputerName

$CertName = "$FQDN"
$FriendlyName = "MSSQL Cert for Windows Server $FQDN"
$dns1 = $MachineName
$dns2 = $FQDN
$dns3 = $IPv4Address
$ipaddress = $IPv4Address

Write-Host "Creating CertificateRequest(CSR) for $CertName `r "

# Create Cert
#
$CSRPath = "$CertFolder\$($CertName).csr"
$INFPath = "$CertFolder\$($CertName).inf"
$Signature = '$Windows NT$' 
 
 
$INF =
@"
[Version]
Signature= "$Signature" 
 
[NewRequest]
Subject = "CN=$CertName, OU=$OU, O=$Company, L=$Location, S=$State, C=US"
FriendlyName = "$FriendlyName"
KeySpec = AT_KEYEXCHANGE
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = False
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0
 
[EnhancedKeyUsageExtension]
 
OID=1.3.6.1.5.5.7.3.1
[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=$dns1&"
_continue_ = "dns=$dns2&"
_continue_ = "dns=$dns3&"
_continue_ = "ipaddress=$ipaddress&"
"@
 
if (!(Test-Path $CSRPath)) {
    Write-Host "Certificate Request is being generated `r "
    $INF | Out-File -filepath $INFPath -force
    & certreq.exe -new $INFPath $CSRPath
}

Write-Output "Certificate Request has been generated"

