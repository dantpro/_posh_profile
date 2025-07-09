#
# https://4sysops.com/archives/find-active-directory-accounts-configured-for-des-and-rc4-kerberos-encryption/
# 
$encTypes = @("Not defined - defaults to RC4_HMAC_MD5",`
    "DES_CBC_CRC",`
    "DES_CBC_MD5",`
    "DES_CBC_CRC | DES_CBC_MD5",`
    "RC4",`
    "DES_CBC_CRC | RC4",`
    "DES_CBC_MD5 | RC4",`
    "DES_CBC_CRC | DES_CBC_MD5 | RC4",`
    "AES 128",`
    "DES_CBC_CRC | AES 128",`
    "DES_CBC_MD5 | AES 128",`
    "DES_CBC_CRC | DES_CBC_MD5 | AES 128",`
    "RC4 | AES 128",`
    "DES_CBC_CRC | RC4 | AES 128",`
    "DES_CBC_MD5 | RC4 | AES 128",`
    "DES_CBC_CBC | DES_CBC_MD5 | RC4 | AES 128",`
    "AES 256",`
    "DES_CBC_CRC | AES 256",`
    "DES_CBC_MD5 | AES 256",`
    "DES_CBC_CRC | DES_CBC_MD5 | AES 256",`
    "RC4 | AES 256",`
    "DES_CBC_CRC | RC4 | AES 256",`
    "DES_CBC_MD5 | RC4 | AES 256",`
    "DES_CBC_CRC | DES_CBC_MD5 | RC4 | AES 256",`
    "AES 128 | AES 256",`
    "DES_CBC_CRC | AES 128 | AES 256",`
    "DES_CBC_MD5 | AES 128 | AES 256",`
    "DES_CBC_MD5 | DES_CBC_MD5 | AES 128 | AES 256",`
    "RC4 | AES 128 | AES 256",`
    "DES_CBC_CRC | RC4 | AES 128 | AES 256",`
    "DES_CBC_MD5 | RC4 | AES 128 | AES 256",`
    "DES+A1:C33_CBC_MD5 | DES_CBC_MD5 | RC4 | AES 128 | AES 256")

$EncVal = Get-ADUser -SearchBase "DC=contoso,DC=dom" `
    -Filter * -properties msDS-SupportedEncryptionTypes

foreach($e in $EncVal){
    try {
        $e.Name + "," + $encTypes[$e.'msDS-SupportedEncryptionTypes']
    }
    catch{
        $e.Name + "," + $encTypes[0]
    }    
}

