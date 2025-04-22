# https://www.powershellgallery.com/packages/CredentialsWithKey/1.10
#

<#==============================================================================
         File Name : CredentialsWithKey.ps1
   Original Author : Kenneth C. Mazie (kcmjr AT kcmjr.com)
                   :
       Description : I've tried numerous times to get a service account password into an 
                   : encrypted file and then recall it.  Sometimes it's worked, sometimes not.
                   : I hit on a few posts that dialed me into a process that seems to work 
                   : reliably.  The result is below.  Its a standalone test script but can 
                   : be easily imported into any script.  What I do is use an XML file as an
                   : external config file and read it when a script starts.  The encoded string this
                   : script creates is suitable for storage this way and recalls cleanly.  I also
                   : include the encrypted AES key in the XML file so both can be read and the 
                   : internals of the calling script can remain generic.   This recovered 
                   : password can be de-crypted by anyone not just the user who encrypted 
                   : it so it works fine for service accounts running automated scripts.  
                   : The script stays in whatever folder you put it in so it's best to 
                   : put it in a new empty folder for testing.
                   :
         Arguments : None
                   :
             Notes : None
                   :
      Requirements : None
                   :  
          Warnings : NOTE !!! This is only nominally secure.  Anyone who knows what they are doing 
                   : can de-crypt the password since BOTH the encryption key and password locations
                   : are available.  This is just to prevent the password from being stored as plain text.
                   :
             Legal : Public Domain. Modify and redistribute freely. No rights reserved.
                   : SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF
                   : ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.
                   :
           Credits : Code snippets and/or ideas came from many sources around the web.
                   :
    Last Update by : Kenneth C. Mazie (email kcmjr AT kcmjr.com for comments or to report bugs)
   Version History : v1.00 - 09-12-16 - Original
    Change History : v1.10 - 03-02-18 - Formatted for upload to PS Gallery
                   :
#===============================================================================#>
<#PSScriptInfo
.VERSION 1.10
.GUID ff96e89e-d400-471f-a33f-8de7663a56a6
.AUTHOR Kenneth C. Mazie (kcmjr AT kcmjr.com)
.DESCRIPTION 
Creates AES encrypted string for use as credentials stored within a script.
#>

Clear-Host

Function RandomKey {   #-[ function creates a random byte string of specified length ]--
      $Length = 32 #16,24, or 32
       $Script:RKey = @()
     For ($i=1; $i -le $Length; $i++) {
     [Byte]$RByte = Get-Random -Minimum 0 -Maximum 256
     $Script:RKey += $RByte
     }
      Return $Script:RKey
}

$ByteArray = RandomKey

$Password_IN = 'MyP@ssw0rd'
$User = "domain\serviceaccount"

write-host "Input password                 :"$Password_IN -ForegroundColor Red
write-host "byte array                     :"$Script:ByteArray -ForegroundColor white

#----------[ Creating AES key with random data and export to file ]-------------
$KeyFile = "$PSScriptRoot\AESkey.txt"
#$RndKey = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($ByteArray)
$Base64String = [System.Convert]::ToBase64String($ByteArray);
$Base64String | out-file $KeyFile
Write-Host "Byte array as base64 string    :"$Base64String -ForegroundColor Cyan

#-------------[ Creating SecureString object ]----------------------------------
$PasswordFile = "$PSScriptRoot\AESPassword.txt"
$KeyFile = "$PSSCriptRoot\AESkey.txt"
$Base64String = (Get-Content $KeyFile)
$ByteArray = [System.Convert]::FromBase64String($Base64String);
$Password = $Password_IN | ConvertTo-SecureString -AsPlainText -Force
$Password | ConvertFrom-SecureString -key $ByteArray | Out-File $PasswordFile

Write-Host "encrypted pwd                  :"(Get-Content $PasswordFile) -ForegroundColor Green

# Creating PSCredential object
$PasswordFile = "$PSScriptRoot\AESPassword.txt"
$KeyFile = "$PSSCriptRoot\AESkey.txt"
$Base64String = (Get-Content $KeyFile)
$ByteArray = [System.Convert]::FromBase64String($Base64String);
write-host "decrypted byte array           :"$ByteArray
 
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $ByteArray)

#----------------------[ Useable result ]---------------------------------------
$Password = $Credential.GetNetworkCredential().Password
$UserID = $Credential.GetNetworkCredential().Username
write-host "decrypted password             :"$Password -ForegroundColor yellow

<#------------------------[ To Recall ]------------------------------------------
To use:
I store the results in an XML file like so...

<Credentials>
    <UserName>domain\serviceaccount</UserName>
    <Password>76492d1116743f8AHIAeEAYQBhAGQANQBkADQAZQAzAGYANAAyADUAYTgBaADcAYwBtAHAWnHbuTOeJWnHbuTOeJFEAPGMAYQBhAGQA2AADEANgBiADA7IXN0I16051/0a534bie8AANwBkADEANAA4AGQAZgA3ADIAYQAwADYAZAA3AGUAZgBkAGYAZAA=</Password>
    <Key>kdWnHbu04234h5M/0a534bie8A13bgBTOeJ7IX605mE=</Key>
</Credentials>

Read the file ...

        [xml]$Script:Configuration = Get-Content $Script:ConfigFile       
        $Script:UserName = $Script:Configuration.Settings.Credentials.Username
        $Script:EncryptedPW = $Script:Configuration.Settings.Credentials.Password
        $Script:Base64String = $Script:Configuration.Settings.Credentials.Key   

Decode and store as variables...
        $ByteArray = [System.Convert]::FromBase64String($Script:Base64String);
        $Script:Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Script:UserName, ($Script:EncryptedPW | ConvertTo-SecureString -Key $ByteArray)
        $Script:Password = $Script:Credential.GetNetworkCredential().Password

#>
    
    
