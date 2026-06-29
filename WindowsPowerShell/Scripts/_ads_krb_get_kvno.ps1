Get-ADComputer -Identity [computer_account_name] -Properties msDS-KeyVersionNumber | Select-Object Name, msDS-KeyVersionNumber

