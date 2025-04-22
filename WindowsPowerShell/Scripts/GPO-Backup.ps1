# https://www.powershellgallery.com/packages/GPO-Backup/1.0
#

Param (
  [Switch]$Console = $false,
  [Switch]$Debug = $False
)
<#======================================================================================
         File Name : GPO-Backup.ps1
   Original Author : Kenneth C. Mazie  (kcmjr AT kcmjr DOT com)
                   : 
       Description : Backs up all group policy settings from current domain.  Creates seperate
                   : folders for each policy using the display name arther than the GUID.  Emails results 
                   : 
             Notes : Normal operation is with no command line options.  
                   : Optional arguments:
                   :   -Console $true  (enables local console output)
                   :   -Debug $true  (redirects email results to debug user)
                   : See example XML file at bottom of script.  XML config must be in the same folder as 
                   : script and named identically.
                   : 
          Warnings : Can be a security risk.  Make sure backups go to a secure location.
                   :   
             Legal : Public Domain. Modify and redistribute freely. No rights reserved.
                   : SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF 
                   : ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.
                   : That being said, please report any bugs you find!!
                   :
           Credits : Code snippets and/or ideas came from many sources including but 
                   :   not limited to the following:
                   : 
                   : 
    Last Update by : Kenneth C. Mazie 
   Version History : v1.00 - 01-16-19 - Original 
                   : v2.00 - 00-00-00 - 
                   :
#=======================================================================================#>
<#PSScriptInfo
.VERSION 1.00
.GUID 61286b4c-33bc-4e5f-91e9-94a187456645
.AUTHOR Kenneth C. Mazie (kcmjr AT kcmjr.com)
.DESCRIPTION 
Backs up all group policy settings from current domain.  Creates seperate folders for each 
policy using the display name arther than the GUID.  Emails results as specified.
#>
#Requires -version 5.0
$ErrorActionPreference = "silentlycontinue"
$ErrorMessage = ""
$Script:EmailBody = ""

If ($Console){$Script:Console = $true}
If ($Debug){$Script:Debug = $true}

#--[ For Testing ]-------------
#$Script:Console = $true
#$Script:Debug = $true
#------------------------------

Function SendEmail ($Script:EmailBody){
    If ($Script:Debug){ $Script:eMailTo = $Script:DebugEmail }
	$msg = new-object System.Net.Mail.MailMessage
    $msg.From = $Script:eMailFrom
    $msg.To.Add($Script:eMailTo)
	$msg.Subject = $Script:eMailSubject
	$msg.IsBodyHtml = $True
	$msg.Body = $Script:EmailBody 
 	$smtp = new-object System.Net.Mail.SmtpClient($Script:SmtpServer)
    $smtp.Send($msg)
    If ($Script:Console){Write-Host "--- Email Sent ---" -ForegroundColor Yellow } 
}

Function ErrorHandling ($ErrorMessage){
    If ($Script:Console){Write-host $ErrorMessage -ForegroundColor magenta}
    SendEmail $ErrorMessage
    Break   
}

Function Messages ($Msg){
    If ($Script:Console){Write-Host $Msg -ForegroundColor Yellow}
    $Script:EmailBody += $Msg+"<br><br>"
}

#--[ End of Functions ]------------------------------------------------------

#--[ Read and load configuration file ]-----------------------------------------
$Script:ScriptName = ($MyInvocation.MyCommand.Name).split(".")[0] 
$Script:ConfigFile = $PSScriptRoot+'\'+$Script:ScriptName+'.xml'

If (!(Test-Path $Script:ConfigFile)){       #--[ Error out if configuration file doesn't exist ]--
    $Script:EmailBody = "--------------------------------------------------------`n" 
    $Script:EmailBody += "--[ GPO Backup MISSING CONFIG FILE.  Script aborted. ]--`n" 
    $Script:EmailBody += "--------------------------------------------------------" 
    Write-Host $Script:EmailBody -ForegroundColor Red
    SendEmail $Script:EmailBody
    break
}Else{
    [xml]$Script:Configuration = Get-Content $Script:ConfigFile       
    $Script:ReportName = $Script:Configuration.Settings.General.ReportName
    $Script:SaveTarget = $Script:Configuration.Settings.General.SaveTarget
    $Script:TargetPath = $Script:Configuration.Settings.General.TargetPath
    $Script:DebugTarget = $Script:Configuration.Settings.General.DebugTarget 
    $Script:EmailSubject = $Script:Configuration.Settings.Email.Subject
    $Script:DebugEmail = $Script:Configuration.Settings.Email.Debug 
    $Script:EmailTo = $Script:Configuration.Settings.Email.To
    $Script:EmailFrom = $Script:Configuration.Settings.Email.From
    $Script:EmailHTML = $Script:Configuration.Settings.Email.HTML
    $Script:SmtpServer = $Script:Configuration.Settings.Email.SmtpServer
    $Script:UN = $Script:Configuration.Settings.Credentials.Username
    $Script:EP = $Script:Configuration.Settings.Credentials.Password
    $Script:DN = (Get-ADDomain -Current LoggedOnUser).DNSroot
    #$Script:DN = $Script:Configuration.Settings.Credentials.Domain      #--[ Use to pull domain from config file ]--
    $Script:B64 = $Script:Configuration.Settings.Credentials.Key   
    $Script:BA = [System.Convert]::FromBase64String($B64)
    $Script:SC = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UN, ($EP | ConvertTo-SecureString -Key $BA)
    #--[ Service account configuration with AES key for hardcoded service account ]--
    #--[ See https://www.powershellgallery.com/packages/CredentialsWithKey/1.10/DisplayScript ]--
}

If ($Script:Console){Write-Host "`n`nBeginning Group Policy Backup Run`n---------------------------------------" -ForegroundColor Green}

#--[ Load the group policy module, install if needed. ]--
If (!(Get-Command -Module grouppolicy)){
    Add-WindowsFeature gpmc
}
Try{
    Import-Module grouppolicy
}Catch{
    Messages $_.Exception.Message
    SendEmail $Script:EmailBody
    break
}    

#--[ Set the date and target path ]-------------------------------
$Date = "GPOBackup_{0:MM-dd-yyyy_HHmmss}" -f (Get-Date)

If ($Debug){
    $Path = $PSScriptRoot
}Else{    
    $Path = $Script:SaveTarget+$Script:TargetPath
}

If (!($Debug)){
    Try{
        $Null = net use \\$Script:SaveTarget\ipc$ /user:$UN $SP
    }Catch{
        Messages $_.Exception.Message
    }
}    

Try{
    #--[ Only keep the last 10 backups, remove the rest ]-----------
    Messages "-- Purging excess backups..."
    Get-ChildItem -Path $Path | Where-Object { $_.PsIsContainer -and $_.name -like "*GPOBackup_*" } | Sort-Object -Descending -Property LastTimeWrite | Select-Object -Skip 10 | Remove-Item -recurse -force #-whatif
    
    #--[ Create a new save folder ]---------------------------------
    $SavePath = $Path+"\"+$Date
    Messages "-- Creating new backup folder: ""$SavePath"""
    $Null = New-Item -Path $SavePath -ItemType directory -force 
}Catch{
    Messages $_.Exception.Message
}
$ErrorActionPreference = "stop"

#--[ Backup all domain GPOs ]----------------------------------------
Try{
    Messages "-- Generating HTML policy report..."
    Get-GpoReport -All -Domain $DN -ReportType "HTML" -Path "$SavePath\PolicyReport.html"
    Messages "-- Compiling list of all existing Group Policies..."
    $PolicyList = Get-GPO -All -Domain $DN

    ForEach ($Policy in $PolicyList) {
        $Msg = "-- Backing up GPO ""{"+$Policy.ID+"}"" as """+$Policy.Displayname+""""
        If ($Script:Console){Messages $Msg}
        $BackupDetail = Backup-GPO -Name $Policy.DisplayName -Path $SavePath -Domain $DN
        #--[ NOTE: The backup is created using the "backup ID" GUID, not the "GPO ID" GUID ]--

        #--[ The next line adds backup details to the console and email. Fromatting is pretty crude as it is ]--
        #--[ If you want formatted detail the $BackupDetail object will require additional processing before going to email ]--
        If ($Script:Console -and $Debug){Messages ($BackupDetail | Out-String)}
        
        #--[ Filter to avoid illegal characters in folder name ]-----------------------
        $FilteredFolderName = $Policy.DisplayName -replace '"|/'  #--[ Add characters to strip out seperated by a pipe symbol | ]

        Rename-Item ($SavePath+"\{"+$BackupDetail.ID+"}") $FilteredFolderName
        sleep -sec 5
    } 
}Catch{
    Messages $_.Exception.Message 
}

If (!($debug)){
    net use \\$Script:SaveTarget\ipc$ /d | Out-Null 
}    

Messages  "-- GPO backup completed.  See result logs in $SavePath for details."
SendEmail $Script:EmailBody


<#--[ Notes ]-----------------------------------------------
    - Data available from GPO:
        DisplayName      : TEST - Test GPO
        DomainName       : domain.com
        Owner            : domin\domain admins
        Id               : 73eb7278-4641-84f1-8221-b24224a98de4
        GpoMessages      : AllSettingsEnabled
        Description      :
        CreationTime     : 12/31/2018 9:50:11 AM
        ModificationTime : 12/31/2018 10:02:22 AM
        UserVersion      : AD Version: 0, SysVol Version: 0
        ComputerVersion  : AD Version: 2, SysVol Version: 2
        WmiFilter        :

    - Data available from backup:
        DisplayName     : TEST - Test GPO
        GpoId           : 73eb7278-4641-84f1-8221-b24224a98de4
        Id              : 92542064-e26c-4c73-a072-c66d33eef502
        BackupDirectory : C:\Temp4\GPOBackup_01-28-2019_095429
        CreationTime    : 1/28/2019 9:54:58 AM
        DomainName      : domain.com
        Comment         :


#--[ XML File Example ]---------------------------------------------------------
<!-- Settings & Configuration File -->
<Settings>
	<General>
		<ReportName>Weekly GPO Backup Report</ReportName>
		<DebugTarget>testpc</DebugTarget>
		<Domain>mydomain.com</Domain>
		<SaveTarget>\\server1</SaveTarget>
		<TargetPath>\d$\Backups\GroupPolicy</TargetPath>
	</General>
	<Email>
		<From>GPO_Backup@mydomain.com</From>
		<To>admin@domain.com</To>
		<Debug>debugemail@mydomain.com</Debug>
		<Subject>Weekly GPO Backup Report</Subject>
		<HTML>$true</HTML>
		<SmtpServer>10.10.10.5</SmtpServer>
	</Email>
	<Credentials>
		<UserName>mydomain\serviceaccount</UserName>
		<Password>76492d1116743f0423413b160HCvLOAHIAegB2AHYAZQAxAGIATwAzAD6/AWAFEAPQA9AHwAYDYAZQBmAGQAOAA0ADEAwADYAZAA3AGUAZgBQANgA0AGEAMAAwADQAAGYANAAyADUAYQA2AGQAZAA2ADQAYwBkAgBaADcAYwBtAH+Eyj267LkAGYAZAA=</Password>
		<Key>kdhCXN0IObie9O+h7HCv6/AWAFEAPQATeJ7IEyj267L6/AWnHbu8mE=</Key>
	</Credentials>
</Settings>	

#>
