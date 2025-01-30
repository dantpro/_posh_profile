$root = "LDAP://dc=contoso,dc=lab"

$ldap_filter = "(&(objectClass=person)(objectClass=user))"                                                      # USERS + COMP
                                                                                                                
#$ldap_filter = '(&(sAMAccountType=805306368))'                                                                 # USERS ALL
#$ldap_filter = '(&(sAMAccountType=805306368)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))'                  # USERS ENABLED
#$ldap_filter = '(&(sAMAccountType=805306368)(useraccountcontrol:1.2.840.113556.1.4.803:=2))'                   # USERS DISABLED
#$ldap_filter = '(&(sAMAccountType=805306368)(lockoutTime:1.2.840.113556.1.4.804:=4294967295))'                 # USERS LOCKED 
#$ldap_filter = '(&(sAMAccountType=805306368)(userAccountControl:1.2.840.113556.1.4.803:=65536))'               # USERS PWD NOT EXPIRED
#$ldap_filter = '(&(samAccountType=805306368)(pwdLastSet=0)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))'    # USERS PWD MUST CHANGE
#$ldap_filter = '(&(samAccountType=805306368)(UserAccountControl:1.2.840.113556.1.4.803:=32))'                  # USERS PWD NOT REQUIRED
#$ldap_filter = '(&(sAMAccountType=805306368)(lastlogontimestamp>=130386096000000000))'                         # USERS LAST LOGON 60
#$ldap_filter = '(&(sAMAccountType=805306368)(lastlogontimestamp>=130360176000000000))'                         # USERS LAST LOGON 90
#$ldap_filter = '(&(sAMAccountType=805306368)(adminCount=1))'                                                   # USERS ADM

#$ldap_filter = '(&(objectCategory=group))'                 # GROUPS ALL
#$ldap_filter = '(&(groupType=-2147483643))'                # GROUPS BUILTIN
#$ldap_filter = '(&(groupType=-2147483640))'                # GROUPS SECURITY UNIVERSAL
#$ldap_filter = '(&(groupType=8))'                          # GROUPS DISTRIBUTION UNIVERSAL
#$ldap_filter = '(&(groupType=-2147483646))'                # GROUPS SECURITY GLOBAL
#$ldap_filter = '(&(groupType=2))'                          # GROUPS DISTRIBUTION GLOBAL
#$ldap_filter = '(&(groupType=-2147483644))'                # GROUPS SECURITY DOMAIN LOCAL
#$ldap_filter = '(&(groupType=4))'                          # GROUPS DISTRIBUTION DOMAIN LOCAL
#$ldap_filter = '(&(objectCategory=group)(adminCount=1))'   # GROUPS ADM 

#$ldap_filter = '(&(objectCategory=computer))'                                                                                                          # COMP ALL
#$ldap_filter = '(&(objectCategory=computer)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))'                                                           # COMP ENABLED
#$ldap_filter = '(&(objectCategory=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2))'                                                            # COMP DISABLED
#$ldap_filter = '(&(objectCategory=computer)(pwdLastSet<=130281552000000000))'                                                                          # COMP INACTIVE 180
#$ldap_filter = '(&(objectCategory=computer)(!useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Windows*)(!operatingSystem=*Server*))'     # COMP WIN WKS ENABLED
#$ldap_filter = '(&(objectCategory=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Windows*)(!operatingSystem=*Server*))'      # COMP WIN WKS DISABLED
#$ldap_filter = '(&(objectCategory=computer)(!useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Server*))'                                 # COMP WIN SRV ENABLED
#$ldap_filter = '(&(objectCategory=computer)(useraccountcontrol:1.2.840.113556.1.4.803:=2)(operatingSystem=*Server*))'                                  # COMP WIN SRV DISABLED
#$ldap_filter = '(&(objectCategory=computer)(!operatingSystem=*Windows*))'                                                                              # COMP NO WIN

$a = [adsisearcher]$ldap_filter

$a.SearchRoot = $root
$a.PageSize = 1000

$a.PropertiesToLoad.add("samaccountname")| Out-Null
$a.PropertiesToLoad.add("distinguishedname")| Out-Null
$results = $a.findall()

$results
"---"
$results.count
