$Searcher = New-Object DirectoryServices.DirectorySearcher

$Searcher.SearchRoot = 'LDAP://dc=contoso,dc=lab'
$Searcher.PageSize = 1000

$Searcher.Filter = '(&(objectClass=person)(objectClass=user))'                                                      # USERS + COMPS

#$Searcher.Filter = '(&(sAMAccountType=805306368))'                                                                 # USERS ALL
#$Searcher.Filter = '(&(sAMAccountType=805306368)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))'                  # USERS ENABLED
#$Searcher.Filter = '(&(sAMAccountType=805306368)(useraccountcontrol:1.2.840.113556.1.4.803:=2))'                   # USERS DISABLED
#$Searcher.Filter = '(&(sAMAccountType=805306368)(lockoutTime:1.2.840.113556.1.4.804:=4294967295))'                 # USERS LOCKED 
#$Searcher.Filter = '(&(sAMAccountType=805306368)(userAccountControl:1.2.840.113556.1.4.803:=65536))'               # USERS PWD NOT EXPIRED
#$Searcher.Filter = '(&(samAccountType=805306368)(pwdLastSet=0)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))'    # USERS PWD MUST CHANGE
#$Searcher.Filter = '(&(samAccountType=805306368)(UserAccountControl:1.2.840.113556.1.4.803:=32))'                  # USERS PWD NOT REQUIRED
#$Searcher.Filter = '(&(sAMAccountType=805306368)(lastlogontimestamp>=130386096000000000))'                         # USERS LAST LOGON 60
#$Searcher.Filter = '(&(sAMAccountType=805306368)(lastlogontimestamp>=130360176000000000))'                         # USERS LAST LOGON 90
#$Searcher.Filter = '(&(sAMAccountType=805306368)(adminCount=1))'                                                   # USERS ADM

#$Searcher.Filter = '(&(objectCategory=group))'                 # GROUPS ALL
#$Searcher.Filter = '(&(groupType=-2147483643))'                # GROUPS BUILTIN
#$Searcher.Filter = '(&(groupType=-2147483640))'                # GROUPS SECURITY UNIVERSAL
#$Searcher.Filter = '(&(groupType=8))'                          # GROUPS DISTRIBUTION UNIVERSAL
#$Searcher.Filter = '(&(groupType=-2147483646))'                # GROUPS SECURITY GLOBAL
#$Searcher.Filter = '(&(groupType=2))'                          # GROUPS DISTRIBUTION GLOBAL
#$Searcher.Filter = '(&(groupType=-2147483644))'                # GROUPS SECURITY DOMAIN LOCAL
#$Searcher.Filter = '(&(groupType=4))'                          # GROUPS DISTRIBUTION DOMAIN LOCAL
#$Searcher.Filter = '(&(objectCategory=group)(adminCount=1))'   # GROUPS ADM 

#$Searcher.Filter = '(&(objectCategory=computer))'                                                                                                          # COMP ALL
#$Searcher.Filter = '(&(objectCategory=computer)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))'                                                           # COMP ENABLED
#$Searcher.Filter = '(&(objectCategory=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2))'                                                            # COMP DISABLED
#$Searcher.Filter = '(&(objectCategory=computer)(pwdLastSet<=130281552000000000))'                                                                          # COMP INACTIVE 180
#$Searcher.Filter = '(&(objectCategory=computer)(!useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Windows*)(!operatingSystem=*Server*))'     # COMP WIN WKS ENABLED
#$Searcher.Filter = '(&(objectCategory=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Windows*)(!operatingSystem=*Server*))'      # COMP WIN WKS DISABLED
#$Searcher.Filter = '(&(objectCategory=computer)(!useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Server*))'                                 # COMP WIN SRV ENABLED
#$Searcher.Filter = '(&(objectCategory=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Server*))'                                  # COMP WIN SRV DISABLED
#$Searcher.Filter = '(&(objectCategory=computer)(!operatingSystem=*Windows*))'                                                                               # COMP NO WIN


$search_result = $Searcher.FindAll() |
    Sort-Object path

foreach ($objTmp in $search_result) {
    Write-Host $objTmp.Properties["cn","adspath"]
}


Write-Host "---"
Write-Host "Number of Obj:" @($search_result).count
Write-Host