# https://www.powershellgallery.com/packages/Audit-Local-Admins/4.10
#
Param(
    [Switch]$Debug = $false,
    [Switch]$Console = $False,
    [Switch]$UseExcel = $True,
    [Switch]$IncludeAdmins = $False,    
    [Switch]$ShortReport = $False    
    )

<#==============================================================================
          File Name : Audit-Local-Admins.ps1
    Original Author : Kenneth C. Mazie 
                    : 
        Description : Queries the local admins group on all domain computers and emails a report on findings.
                    : 
              Notes : Normal operation is with no command line options.  Basic log is written to C:\Scripts
                    : Optional argument: -Debug $true (defaults to false.  Changes runtime options, email recipient, sets UseExcel to false) 
                    :                    -Console $true (displays runtime info on console)
                    :                    -UseExcel $false (defaults to $true. Creates an Excel spreadsheet and stores the last 10.  Attaches to outgoing email by default.)
                    :                    -IncludeAdmins $true (defaults to $false. Will include entries on the administrators array in the final report)
                    :                    -LongReport $true (defaults to $false.  Will include ALL systems.  Short report only adds a system to the output if anomalies are found)
                    : 
           Warnings : None
                    :   
              Legal : Public Domain. Modify and redistribute freely. No rights reserved.
                    : SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF 
                    : ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.
                    :
            Credits : Code snippets and/or ideas came from many sources including but 
                    :   not limited to the following:
                    : N/A
                    : 
     Last Update by : Kenneth C. Mazie 
    Version History : v1.00 - 09-16-13 - Original 
     Change History : v1.10 - 04-19-15 - Edited to allow color coding of HTML output, only keep 10 XLSX files.
                    : v1.20 - 02-02-16 - Fixed lock up after closing Excel.
                    : v1.30 - 03-10-16 - Corrected spreadsheet attachment error. Added admin ignore option
                    : v2.00 - 02-02-18 - Major rewrite for PS 5.1.  Added external config file to genericize script.
                    :                    Altered report output formatting.
                    : v2.10 - 03-15-18 - Tweaked for upload to PS Gallery.
                    : v2.20 - 06-18-18 - Adjusted local administrator decoy detection so if a local user named "administrator"
                    :                    is found with a non-standard SID it gets flagged.
                    : v3.00 - 07-13-18 - Complete rewrite.  Changed report generation, changed arguments, added color to excel
                    :                    tweaked messages, added detection of permission issues.
                    : v4.00 - 07-31-18 - Results not displaying to my liking, rewrote "includetarget" section to produce proper output.
                    :                    HOPEFULLY I got it right this time...
                    : v4.10 - 07-31-18 - Forgot to disable testing options before commit.  NOTE new option in XML config file...
                    :
#===============================================================================#>
<#PSScriptInfo
.VERSION 4.10
.GUID 77f578dc-4887-44b2-b981-783aba19755d
.AUTHOR Kenneth C. Mazie (kcmjr AT kcmjr.com)
.DESCRIPTION 
Queries the local admins group on all domain computers.  Finds linked admin accounts that should not be in the admin group,
also finds default, renamed, and decoy admin accounts.  Emails a report on findings..
#>
#requires -version 5.1
Clear-Host 
    
If ($Debug){$Script:Debug = $True}
If ($Console){$Script:Console = $True}
If ($UseExcel){$Script:UseExcel = $True} 
If ($IncludeAdmins){$Script:IncludeAdmins = $True} 
If ($Debug){$Script:UseExcel = $False} 
If ($ShortReport){$Script:ShortReport = $True}

$ErrorActionPreference = "silentlycontinue"

#--[ Manual bypass options ]---------
#$Script:Console = $True
#$Script:Debug = $True
#$Script:UseExcel = $true
#$Script:IncludeAdmins = $false
#$Script:ShortReport = $false
#------------------------------------

#--[ Functions ]-------------------------------------------------------------------------
Function LoadModules {
    If (!(Get-module ActiveDirectory)){Import-Module ActiveDirectory}
}    

Function LoadConfig { #--[ Read and load configuration file ]-----------------------------------------
    If (!(Test-Path $Script:ConfigFile)){       #--[ Error out if configuration file doesn't exist ]--
        $Script:EmailBody = "---------------------------------------------`n" 
        $Script:EmailBody += "--[ MISSING CONFIG FILE.  Script aborted. ]--`n" 
        $Script:EmailBody += "---------------------------------------------" 
        #SendEmail    #--[ No email without the settings file.  Preset the options if you like ]--
        Write-Host $EmailBody -ForegroundColor Red
        break
    }Else{
        [xml]$Script:Configuration = Get-Content $Script:ConfigFile      
        $Script:DebugTarget = $Script:Configuration.Settings.General.DebugTarget
        $Script:ExclusionList = ($Script:Configuration.Settings.General.Exclusions).Split(",")
        $Script:RenamePattern = $Script:Configuration.Settings.General.RenamePattern
        $Script:ValidAdmins = ($Script:Configuration.Settings.General.ValidAdmins).Split(",")
        $Script:ReportName = $Script:Configuration.Settings.General.ReportName
        $Script:Domain = $Script:Configuration.Settings.General.Domain
        $Script:DebugEmail = $Script:Configuration.Settings.Email.Debug 
        $Script:eMailTo = $Script:Configuration.Settings.Email.To
        $Script:eMailFrom = $Script:Configuration.Settings.Email.From    
        $Script:eMailHTML = $Script:Configuration.Settings.Email.HTML
        $Script:eMailSubject = $Script:Configuration.Settings.Email.Subject
        $Script:SmtpServer = $Script:Configuration.Settings.Email.SmtpServer
        $Script:CredUserName = $Script:Configuration.Settings.Credentials.Username
        $Script:EncryptedPW = $Script:Configuration.Settings.Credentials.Password
        $Script:Base64String = $Script:Configuration.Settings.Credentials.Key   
        $ByteArray = [System.Convert]::FromBase64String($Base64String)
        $Script:Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Script:CredUserName, ($EncryptedPW | ConvertTo-SecureString -Key $ByteArray)
        $Script:Password = $Credential.GetNetworkCredential().Password    
    }
}

Function SendEmail {
    $email = $null
    If ($Script:Debug){$ErrorActionPreference = "stop"}
    $eMailBody = $Script:ReportName 
    If ($Script:Debug){
        $eMailRecipient = $Script:DebugEmail                                        #--[ Debug destination email address 
    }Else{    
        $eMailRecipient = $Script:eMailTo                                           #--[ Destination email address 
    }
    $emailFrom = $Script:eMailFrom                                                  #--[ Sender address.
    $email = New-Object System.Net.Mail.MailMessage
    $email.From = $Script:eMailFrom
    $email.IsBodyHtml = $Script:eMailHTML
    $email.To.Add($eMailRecipient)
    $email.Subject = $Script:eMailSubject
    If ($Script:UseExcel){
        $email.Attachments.Add($Script:FileName)
    }      
    $email.Body = $Script:ReportBody 
    $smtp = new-object Net.Mail.SmtpClient($Script:SmtpServer)
    $smtp.Send($email)
    If ($Script:Console){Write-Host "`n--[ Email sent ]--" -ForegroundColor Green}
}

Function GetTargets {
    $Script:TargetList =  ""
    If ($Script:Debug){
        $Script:TargetList = @(Get-ADComputer -Credential $Credential  -Filter "Name -Like '*$Script:DebugTarget*'" -ErrorAction 0 | Select Name | Sort Name)
        Write-Host "-- DEBUG MODE --" -ForegroundColor red 
    }Else{
        $Script:TargetList = @(Get-ADComputer -Credential $Credential -Filter * | select name | sort name)
    }    
    $Script:Count = $Script:TargetList.count
}

#==[ Main Body ]================================================================
$Script:ReportBody = ""
$HtmlData = ""
$DayOfWeek = (get-date).DayOfWeek
$StartTime = [datetime]::Now
# $Domain = (Get-ADDomain).DNSroot      #--[ Alternate ]--
$Computer = $Env:ComputerName
$Script:Message = ""
$ScriptName = ($MyInvocation.MyCommand.Name).split(".")[0] 
$Script:LogFile = "$PSScriptRoot\$ScriptName-{0:MM-dd-yyyy_HHmmss}.html" -f (Get-Date)  
$Script:ConfigFile = "$PSScriptRoot\$ScriptName.xml"  
LoadConfig 
LoadModules
GetTargets

#--[ Add header to html log file ]--
$Script:ReportBody = @() 
$Script:ReportBody += '
<style type="text/css">
    table.myTable { border:5px solid black;border-collapse:collapse; }
    table.myTable td { border:2px solid black;padding:5px;background: #E6E6E6 } 
    table.myTable th { border:2px solid black;padding:5px;background: #B4B4AB }
    table.bottomBorder { border-collapse:collapse; }
    table.bottomBorder td, table.bottomBorder th { border-bottom:1px dotted black;padding:5px; }
</style>'

$Script:ReportBody += '<table class="myTable">'
$Script:ReportBody += '<tr><td colspan=4><center><h1>-- '+$Script:ReportName+' Report --</h1></center></td></tr>'
If ($Script:ShortReport ){
    $Script:ReportBody += "<tr><td colspan=4><center>The following report displays members of the local administrators group for servers and/or PCs that don't belong.</center></td></tr>"
}Else{
    $Script:ReportBody += '<tr><td colspan=4><center>The following report displays all members of the local administrators group for every server and PC in the domain.</center></td></tr>'
}

#--[ Excel Non-Interactive Fix ]------------------------------------------------
#--[ Excel will crash when run non-interactively via a scheduled task if these folders don't exist.  Folder permissions may cause this to fail. Creation may fail due to permission issues. ]--
Try{
    If (!(Test-path -Path "C:\Windows\System32\config\systemprofile\Desktop")){New-Item -Type Directory -Name "C:\Windows\System32\config\systemprofile\Desktop" -ErrorAction "SilentlyContinue" -Force}
    If (!(Test-path -Path "C:\Windows\SysWOW64\config\systemprofile\Desktop")){New-Item -Type Directory -Name "C:\Windows\SysWOW64\config\systemprofile\Desktop" -ErrorAction "SilentlyContinue" -Force}
}Catch{}    

#--[ Detect Excel, use it and send attachment if found, otherwise only create HTML ]--
$Script:NoExcel = $False
if (!(get-itemproperty hklm:\software\microsoft\windows\currentversion\uninstall\* | select displayname | where {$_.displayname -like "*Office*"} -ne "")){
    $Script:UseExcel = $False
    $Script:NoExcel = $True
    $Script:ReportBody += '<tr><td colspan=4><center>NOTICE: Excel was not located on the system running this report.  No spreadsheet will be included.</center></td></tr>'
}

If ($Script:UseExcel){
    $Row = 0
    $Col = 1
    #--[ Create a new Excel object ]--
    $Excel = New-Object -Com Excel.Application
    If ($Script:Console -or $Script:Debug){
        $Excel.visible = $True
        $Excel.DisplayAlerts = $true
        $Excel.ScreenUpdating = $true
        $Excel.UserControl = $true
        $Excel.Interactive = $true
    }Else{
        $Excel.visible = $False
        $Excel.DisplayAlerts = $false 
        $Excel.ScreenUpdating = $false 
        $Excel.UserControl = $false
        $Excel.Interactive = $false
    }
    $Workbook = $Excel.Workbooks.Add()
    $WorkSheet = $Workbook.WorkSheets.Item(1)
   
    #--[ Write Worksheet title ]--
    $WorkSheet.Cells.Item($Row,1) = "Local Administrator Audit Report - $DateTime"
    $WorkSheet.Cells.Item($Row,1).font.bold = $true
    $WorkSheet.Cells.Item($Row,1).font.underline = $true
    $WorkSheet.Cells.Item($Row,1).font.size = 18
    #--[ Write worksheet column headers ]--
    $Row ++
    $WorkSheet.Cells.Item($Row,$Col) = "TARGET:"
    $WorkSheet.Cells.Item($Row,$Col).font.bold = $true
    $WorkSheet.Cells.Item($Row,$Col).HorizontalAlignment = 1
#    $WorkSheet.Cells.Item($Row,$Col).Borders.Item(10).LineStyle = 1     #--[ optional formatting ]--
#    $WorkSheet.Cells.Item($Row,$Col).Borders.Item(10).Weight = 4
    $Col++
    $WorkSheet.Cells.Item($Row,$Col) = "PING CHECK:"
    $WorkSheet.Cells.Item($Row,$Col).font.bold = $true
    $WorkSheet.Cells.Item($Row,$Col).HorizontalAlignment = 1
#    $WorkSheet.Cells.Item($Row,$Col).Borders.Item(10).LineStyle = 1
#    $WorkSheet.Cells.Item($Row,$Col).Borders.Item(10).Weight = 4
    $Col++
    $WorkSheet.Cells.Item($Row,$Col) = "USER:"
    $WorkSheet.Cells.Item($Row,$Col).font.bold = $true
    $WorkSheet.Cells.Item($Row,$Col).HorizontalAlignment = 1
#    $WorkSheet.Cells.Item($Row,$Col).Borders.Item(10).LineStyle = 1
#    $WorkSheet.Cells.Item($Row,$Col).Borders.Item(10).Weight = 4
    $WorkSheet.application.activewindow.splitcolumn = 0
    $WorkSheet.Cells.Item(2,1).Select
#    $WorkSheet.application.activewindow.splitrow = 1
    $WorkSheet.application.activewindow.freezepanes = $true
    $Resize = $WorkSheet.UsedRange
    [void]$Resize.EntireColumn.AutoFit()
}

#--[ HTML Report Header ]--
$Script:ReportBody += '<tr><th>Target System</th><th>Account Name</th><th>Account Location</th><th>Account Type</th></tr>'
    
$Row ++
If ($Script:Console){
    Write-Host "`n--- BEGIN ---" -ForegroundColor Green
    Write-Host "`nTotal Target Systems = $Count" -ForegroundColor Cyan 
}
$Remaining = 0 #$Count

ForEach ($Target in $TargetList){
    $Target = $Target.name
    $IncludeTarget = $true                 #--[ The default is to add all targets to Excel, HTML, and ALWAYS to console ]--
    $AddSystem = $false                    #--[ By default we do NOT add the system to Excel or HTML, only on display ]--
    $AddRow = $False                       #--[ This determines if the individual row is included in output ]--
    $HtmlRowData = ""
    $HtmlSystemData = ""  
    $Anomaly = $False                      #--[ Flag for filtering "brief" report ]--  
    $Col = 1
    $SIDprefix = ""
    $SIDsuffix = ""
    $UserName = ""
    $AcctLocation = ""

    If ($Script:Console){Write-Host "`n------ [ Target System = $Target     ("($Remaining+1)"of $Count ) ]---------------------------" -ForegroundColor Cyan }

    $Script:ExclusionList | ForEach-Object {                      #--[ Create a flag to denote when a system should be bypassed ]--
        if ($Target -match $_){$IncludeTarget = $False} 
    }       
    If ($Target -eq $ENV:ComputerName){$IncludeTarget = $False}   #--[ Don't include the local computer ]--
 
    $WorkSheet.Cells.Item($row,$col) = $Target
    $Col ++

    If($IncludeTarget){                     #--[ Include these systems ]--
        if (Test-Connection -ComputerName $Target -count 1 -BufferSize 16 -ErrorAction SilentlyContinue){ 
            $WorkSheet.Cells.Item($row,$col).font.colorindex = 10
            $WorkSheet.Cells.Item($row,$col) = "OK";$Col ++
            If ($Script:Debug){
                $HtmlSystemData += '<tr><td><font color=darkcyan><strong>' + $Target.ToUpper() + '</strong></td><td colspan=3>Ping Check: <font color=darkgreen>OK</font>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font color=#a0a0a0>( Target '+($Remaining+1)+' of '+$Count+' Targets Total, '+($Count-($Remaining+1))+' Remaining.  )</font></td></tr>'
            }Else{
                $HtmlSystemData += '<tr><td><font color=darkcyan><strong>' + $Target.ToUpper() + '</strong></td><td colspan=3>Ping Check: <font color=darkgreen>OK</font></td></tr>'
            }
            
            #--[ Get list of users in local admin group ]--
            Try{
                $AdminList = Invoke-Command -ScriptBlock {Get-LocalGroupMember -Group "Administrators"} -ComputerName $Target -Credential $Credential
                If ($Script:Debug){Write-Host "Admin Count 1: "$AdminList.count -ForegroundColor Magenta}
                $AdminCount2 = $False
            }Catch{
                If ($Script:Debug){
                    Write-Host "------- Access Error: ------" -ForegroundColor red
                    $_.Exception.Message
                    $_.Exception.ItemName
                    Write-host "----------------------------" -ForegroundColor red
                }
            }   

            If($AdminList.count -eq 0){    #--[ Try WMI instead ]--
                Try{
                    $AdminList = Get-WmiObject -computername $Target -Class win32_groupuser -ErrorAction "SilentlyContinue" -Credential $Script:Credential  | WHERE {$_.groupcomponent -match 'administrators' } | foreach {[WMI]$_.partcomponent } 
                    If ($Script:Debug){Write-Host "Admin Count 2: "$AdminList.count -ForegroundColor magenta}
                    $AdminCount2 = $True
                }Catch{
                    If ($Script:Debug){
                        Write-Host "------- Access Error: ------" -ForegroundColor red
                        $_.Exception.Message
                        $_.Exception.ItemName
                        Write-host "----------------------------" -ForegroundColor red

                    }
                }
            }
            
            #--[ Get list of local users with WMI to check for decoy account. ]--
            [Array]$LocalAccounts = Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" -Filter "LocalAccount='$True'" -ComputerName $Script:Target -Credential $Script:Credential -ErrorAction silentlycontinue 
            If ($Script:Debug){Write-Host "   User Count: "$LocalAccounts.Count -ForegroundColor Magenta}

            If($AdminList.count -eq 0){  #--[ There has been an error accessing the target ]--
                $Anomaly = $true
                If ($Script:Console){
                    Write-Host "        ERROR:  Cannot read the Administrators group!!!" -ForegroundColor Red
                }    
                $HtmlRowData += '<tr><td><font color=darkcyan><strong>&nbsp;</td><td colspan=3><font color=darkmagenta>There was an error accessing the target Administrators group...</font></td></tr>'   
                $WorkSheet.Cells.Item($row,$col).font.colorindex = 13
                $WorkSheet.Cells.Item($row,$col) = "Error accessing Administrators group"
                $Script:HtmlSystemData += $HtmlRowData 
            }Else{
                #--[ Process each user in Administrators group ]-------------------------------------------------------------------
                ForEach ($UserObject in $AdminList){ 
                    $HtmlRowData = '<tr><td>&nbsp;</td>'
                    $AddRow = $False

                    #--[ Well known SID identifiers:  https://support.microsoft.com/en-us/help/243330/well-known-security-identifiers-in-windows-operating-systems ]--
                    $SIDprefix = $UserObject.SID.SubString(0,6)                               #--[ Well known NT Authority prefix = "S-1-5" ]--
                    $SIDsuffix = $UserObject.SID.SubString($UserObject.SID.Length - 4)        #--[ Well known NT Authority suffix = "-500" ]--
                    
                    If ($AdminCount2){
                        $UserName = $UserObject.Caption.Split("\")[1].ToLower() 
                        $AcctLocation = $UserObject.Caption.Split("\")[0].ToLower()
                    }Else{
                        $UserName = $UserObject.Name.Split("\")[1].ToLower() 
                        $AcctLocation = $UserObject.Name.Split("\")[0].ToLower()
                    }     

                    If ($Script:Console){
                        Write-Host "        Found: "$UserName -ForegroundColor Yellow -NoNewline
                        Write-Host "   ("$UserObject.SID")" -ForegroundColor Gray -NoNewline
                    }                   
                    
                    If ($UserName -eq "Administrator"){                                 #--[ Validate the administrator account is or is not a decoy ]--                        
                        If (($SIDprefix -eq "S-1-5-") -and ($SIDsuffix -eq "-500")){    #--[ Valid SID for default admin ]--
                            If ($Script:Console){Write-Host "    (Default)" -ForegroundColor red}
                            $HtmlRowData += '<td><font color=darkred>' + $UserName + "  (Default)"+'</td>'
                            $HtmlRowData += '<td><font color=darkred>' + $AcctLocation +'</td>'
                            $WorkSheet.Cells.Item($row,$col).font.colorindex = 3
                            $WorkSheet.Cells.Item($row,$col) = $UserName+"  (Default)"
                            $AddRow = $True
                            $Anomaly = $true
                        }Else{
                            If ($Script:Console){Write-host " -- DECOY ADMIN ACCOUNT IDENTIFIED --" -ForegroundColor Magenta }
                            $HtmlRowData += '<td><font color=darkgreen>' + $UserName+ ' (Decoy)'+'</td>'
                            $HtmlRowData += '<td><font color=darkgreen>' + $AcctLocation+'</td>'
                            $WorkSheet.Cells.Item($row,$col).font.colorindex = 10
                            $WorkSheet.Cells.Item($row,$col) = $UserName+"  (Decoy)"
                            If($Script:IncludeAdmins){$AddRow = $true} 
                        }                     
                    }ElseIf ($Script:ValidAdmins -Contains $UserName){                         #--[ Inspect valid admins array to see if this user is on it ]--
                        If (($UserName -like $Script:RenamePattern) -and ($SIDsuffix -ne "-500")){
                            If ($Script:Console){Write-host " -- CORRUPTED DECOY ADMIN ACCOUNT IDENTIFIED --" -ForegroundColor Red }
                            $HtmlRowData += '<td><font color=darkred>' + $UserName + ' (CORRUPTED)'+'</td>'
                            $HtmlRowData += '<td><font color=darkred>' + $AcctLocation+'</td>'
                            $WorkSheet.Cells.Item($row,$col).font.colorindex = 3
                            $WorkSheet.Cells.Item($row,$col) = $UserName+"  (CORRUPTED)"
                            $AddRow = $True
                            $Anomaly = $true
                        }Else{
                            If ($UserName -like $Script:RenamePattern){ 
                                If ($Script:Console){Write-Host "   (Valid Renamed Admin)" -ForegroundColor Green}
                            }Else{
                                If ($Script:Console){Write-Host "   (Valid Admin)" -ForegroundColor Green}
                            }    
                            $HtmlRowData += '<td><font color=darkgreen>' + $UserName+'</td>'
                            $HtmlRowData += '<td><font color=darkgreen>' + $AcctLocation+'</td>'
                            $WorkSheet.Cells.Item($row,$col).font.colorindex = 10
                            $WorkSheet.Cells.Item($row,$col) = $UserName #+"  (Valid)"
                            If($Script:IncludeAdmins){$AddRow = $true}                    #--[ Add the user only if we want valid admins ]--
                        }
                    }Else{                                                                #--[ If we get here it's a bad user ]--
                        $Anomaly = $true
                        $AddRow = $True
                        If (($UserName -ne "Administrator") -and ($Script:Console)){Write-Host "  (BAD)" -ForegroundColor Red }
                        $HtmlRowData += '<td><font color=darkred>' + $UserName+'</td>'
                        $HtmlRowData += '<td><font color=darkred>' + $AcctLocation+'</td>'
                        $WorkSheet.Cells.Item($row,$col).font.colorindex = 3
                        $WorkSheet.Cells.Item($row,$col) = $UserName #+"  (BAD)"
                    }    


                    If ($UserObject.PrincipalSource -ne "local"){                         #--[ Is the account local or domain? ]--
                        $HtmlRowData += '<td><font color=darkblue>Domain '+$UserObject.Class+'</td>'
                    }Else{
                        $HtmlRowData += '<td><font color=#ff8000>Local '+$UserObject.Class+'</td>'
                    }

                    $HtmlRowData += '</tr>'     #--[ End the HTML row ]--
                    $Col++

                    If ($AddRow){ # -or $Script:LongReport)  { 
                        $Script:HtmlSystemData += $HtmlRowData
                    }
                }          
                #--[ End of User Processing ]------------------------------------------------------------------------------------------   
            }  
        }Else{
            if ($Script:Console){Write-Host "        System does not respond to ping..." -ForegroundColor Red }
            $Anomaly = $True
            $WorkSheet.Cells.Item($row,$col).font.colorindex = 3
            $WorkSheet.Cells.Item($row,$col) = "OFFLINE"
            $HtmlRowData += '<tr><td><font color=darkcyan><strong>' + $Target + '</td><td colspan=3>Ping Check:<font color=darkred> FAILED</font>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font color=#909090>( Target '+($Count-($Remaining-1)) +' of '+$Count+' Targets Total, '+($Remaining-1)+' Remaining.  )</font></td></tr>'
            $Script:HtmlSystemData += $HtmlRowData
            $AddSystem = $True
        } 
    }Else{  #--[ Bypass these systems ]--
        if ($Script:Console){Write-Host "        System is on the exclusion list..." -ForegroundColor Magenta }
        $Anomaly = $True
        $WorkSheet.Cells.Item($row,$col).font.colorindex = 13
        $WorkSheet.Cells.Item($row,$col) = "EXCLUDED"

        If ($Script:Debug){
            $HtmlRowData += '<tr><td><font color=darkcyan><strong>' + $Target.ToUpper() + '</td><td colspan=3><font color=darkmagenta>Target is on the exclusion list.</font>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font color=#909090>( Target '+($Remaining+1) +' of '+$Count+' Targets Total, '+$Remaining+' Remaining.  )</font></td></tr>'
         }Else{    
            $HtmlRowData += '<tr><td><font color=darkcyan><strong>' + $Target.ToUpper() + '</td><td colspan=3><font color=darkmagenta>Target is on the exclusion list.</font></td></tr>'   
        }             
       
        $Script:HtmlSystemData += $HtmlRowData   #--[ Add the HTML row data to HTML system data ]--
    }  #--[ End of system inclusion loop ]--   
    
    If ((!$Script:ShortReport) -or $Anomaly){
       $Script:ReportBody += $Script:HtmlSystemData    #--[ Add HTML system data to HTML report only if anomaly found or short report not selected ]--
    }

    $Remaining ++
    $Row ++
    $Resize = $WorkSheet.UsedRange
    [void]$Resize.EntireColumn.AutoFit()
}

$Script:ReportBody += '</table>'
$Script:ReportBody += '<br><font color=#909090>Script "'+$MyInvocation.MyCommand.Name+'" executed from "'+$env:computername+'".<br>'

$Resize = $WorkSheet.UsedRange
[Void]$Resize.EntireColumn.AutoFit()

[string]$DateTime = Get-Date -Format MM-dd-yyyy_HHmmss 
[string]$Script:FileName = "$PSScriptRoot\LocalAdminUserAudit_$DateTime.xlsx"
If ($UseExcel){    
    Try{
        $Workbook.SaveAs($Script:FileName)
        $Workbook.Saved = $true 
        $Workbook.Close() 
        $Excel.Quit()
        $Excel = $Null
        if ($Script:Debug){Write-host "`nExcel Closed and Saved...`n" -ForegroundColor Cyan}
    }Catch{    
        if ($Script:Debug){Write-host "`nThere was a problem closing and/or Saving the Excel spreadsheet...`n" -ForegroundColor Red}
    }    
}    

#--[ Removing any older Excel files.  Retaining ten most recent. ]--
###Get-ChildItem -Path "$PSScriptRoot\*.xlsx" | Where-Object { -not $_.PsIsContainer } | Sort-Object -Descending -Property LastTimeWrite | Select-Object -Skip 10 | Remove-Item         
If (!$Script:Debug){Get-ChildItem -Path "$PSScriptRoot\" | Where-Object { -not $_.PsIsContainer -and $_.name -like "*.xlsx" } | Sort-Object -Descending -Property LastTimeWrite | Select-Object -Skip 10 | Remove-Item }

$Script:ReportBody += '</table><br>'
$x = 0
If ($Script:NoExcel){
    $Script:ReportBody += '<br>NOTICE: Spreadsheet not included because Excel was not found on the system running this script.  Install Excel to include the spreadsheet.<br>'
}    
$Script:ReportBody += 'The following list contains all users/groups that are ignored by this report unless the "includeadmins" option is expressly selected.'
$Script:ReportBody += '<br>If "Administrator" is noted as (DECOY) it means an admin account was detected but has a non-default SID.  These are usually decoy'
$Script:ReportBody += '<br>accounts but should NOT be in the local admin group.'
$Script:ReportBody += '<br><br>These are considered "known" accounts and are expected to be found.  All others are anomalous:<br>'

if ($Script:Debug){Write-host "`nIgnored Admin Accounts:" }
While ($x -lt $Script:ValidAdmins.Count ){
    if ($Script:Debug){Write-host "-- "$Script:ValidAdmins[$x] }
    $Script:ReportBody += " - "+$Script:ValidAdmins[$x]+"<br>"
    $x++
}

$Script:ReportBody += '<br>Color scheme:<br> - Green User = Expected<br> - Red User = Investigate'
$Script:ReportBody += '<br> - Gray User = Ignored<br> - Orange Type = Local Resource<br> - Blue Type = Domain Resource'
If ($Debug){
    $Script:ReportBody += '<br><br>Script runtime options:'
    If ($Debug){$Script:ReportBody += '<br> - Debug option ENABLED'}
    If ($Console){$Script:ReportBody += '<br> - Console option ENABLED'}
    If (!$Script:UseExcel){$Script:ReportBody += '<br> - Excel option DISABLED'}
    If ($IncludeAdmins){$Script:ReportBody += '<br> - IncludeAdmins option ENABLED'}
    If ($Script:ShortReport){$Script:ReportBody += '<br> - ShortReport option ENABLED'}
    $Script:ReportBody += '<br>'
}

SendEmail 

[gc]::Collect()
[gc]::WaitForPendingFinalizers()

if ($Script:Debug){Write-host "`nCompleted..." }


<#--[ XML Config File Example ]-------------------------------------------------------------------------

<!-- Settings & Configuration File -->
<Settings>
    <General>
        <ReportName>Local Administrator Audit</ReportName>
        <DebugTarget>testpc</DebugTarget>                      <!-- Partial names OK to include a group -->
        <ValidAdmins>Local_Admin_Grp-1,Local_Admin_Grp-2,localadmin,administrator</ValidAdmins>
        <Exclusions>pc27,pc01</Exclusions>
      	<RenamePattern>new*admin</RenamePattern>      <!-- This is the pattern used for renamed admin accounts -->
        <Domain>mydomain.com</Domain>
    </General>
    <Email>
        <From>MonthlyReports@mydomain.com</From>
        <To>admin@mydomain.com</To>
        <Debug>me@mydomain.com</Debug>
        <Subject>Local Administrator Audit</Subject>
        <HTML>$true</HTML>
        <SmtpServer>10.10.5.5</SmtpServer>
    </Email>
    <Credentials>
        <UserName>domain\serviceaccount</UserName>
        <Password>766743f0423413AegMAYQBhAGEAYQBhAGQANQBkADQAZQAzAGYANAAyADUGIATgiAwADYAZAA3AGUAZgGADQAYwBkADYAZQBmAGQAOAA0ADEANgBiAAYQA2AGQAZAA2B2AHYAZQAxAGIATgBaADAEcAaAB1AFEAPQA9AHwAYwAzADQANgADAANwAGQAZgA3ADIAYQABkAGYAZAA=</Password>
        <Key>kdhICvLO+eJ76/AWnHbXN0IObEyjuTie8mE=</Key>
    </Credentials>
</Settings>    




#>