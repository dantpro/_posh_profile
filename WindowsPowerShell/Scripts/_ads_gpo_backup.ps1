#https://jm2k69.github.io/2020/04/GPO-from-zero-to-hero-How-to-backup-GPO.html

$domain = "contoso.lab"
$server = "srv-adc-1.contoso.lab"

$backup_date = $(Get-Date -Format "yyMMdd_HHmmss")

$AllGPOs = Get-GPO -All -domain $domain -server $server

foreach ($GPO in $AllGPOs) {

  $GPODisplayName = $GPO.DisplayName
  $GPOGuid = $GPO.id

  $HTMLReportFile = '.\GPO_BKP\' +$domain + '\' + $backup_date + '\' + $GPODisplayName +'.html'
  $XMLReportFile = '.\GPO_BKP\' +$domain + '\' + $backup_date + '\' + $GPODisplayName +'.xml'
  $GPOBackupDst = '.\GPO_BKP\' +$domain + '\' + $backup_date + '\' + $GPODisplayName + '\'

  if (-Not (Test-Path $GPOBackupDst)) {
      New-Item -Path $GPOBackupDst -ItemType directory | Out-Null
      Backup-GPO -Name $GPO.DisplayName -domain $domain -server $server -Path $GPOBackupDst
      
      Get-GPOReport -Guid $GPOGuid -ReportType HTML -domain $domain -server $server -Path $HTMLReportFile
      Get-GPOReport -Guid $GPOGuid -ReportType XML -domain $domain -server $server -Path $XMLReportFile
      }
  }

