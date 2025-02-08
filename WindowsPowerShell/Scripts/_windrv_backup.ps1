# https://winitpro.ru/index.php/2014/07/31/eksport-drajverov-s-pomoshhyu-powershell-v-windows-8-1-u1/

Export-WindowsDriver –Online -Destination C:\-\drv\
# & "dism /online /export-driver /destination:C:\-\drv"

# & "pnputil.exe /add-driver C:\-\drv\*.inf /subdirs /install"

# $BackupDrv = Export-WindowsDriver -Online -Destination C:\-\drv\
# $BackupDrv | Select-Object ClassName, ProviderName, Date, Version | Sort-Object ClassName

# $BackupDrv| Select-Object ClassName, ProviderName, Date, Version |
#    Export-Csv C:\-\drv\drivers_list.csv -NoTypeInformation -Encoding UTF8

# pnputil.exe /enum-drivers
# pnputil.exe /add-driver C:\#\DRV\_EXP\*.inf /subdirs /install

# Get-WindowsDriver -Online | where { ($_.ProviderName -like "Realtek") –and ($_.ClassName -like "Net")}
# Mkdir C:\-\drv\realtek
# pnputil.exe /export-driver oem20.inf C:\-\drv\realtek\
