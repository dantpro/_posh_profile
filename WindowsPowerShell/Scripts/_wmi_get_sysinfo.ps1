# https://winitpro.ru/index.php/2012/01/13/filtraciya-gruppovyx-politik-s-pomoshhyu-wmi-filtrov/

Get-WmiObject -ComputerName localhost -Query "SELECT * FROM Win32_OperatingSystem WHERE ProductType=1"

# wks - client
Get-CimInstance -ComputerName localhost -Query "SELECT * FROM Win32_OperatingSystem WHERE ProductType=1" |Format-List

# srv - server
Get-CimInstance -ComputerName localhost -Query "SELECT * FROM Win32_OperatingSystem WHERE ProductType=3" |Format-List

# adc - domain controller
Get-CimInstance -ComputerName localhost -Query "SELECT * FROM Win32_OperatingSystem WHERE ProductType=2" |Format-List

# laptop
Get-CimInstance -ComputerName localhost -Query "SELECT * FROM Win32_ComputerSystem WHERE PCSystemType = 2" |Format-List



