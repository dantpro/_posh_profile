# https://www.powershellgallery.com/packages/DomainPurge/4.22
#
Param (
  [Switch]$Debug = $false,             
  [Switch]$Console = $false,
  [Switch]$FullReport = $False,
  [Switch]$NoPurge = $False,
  [Switch]$UsePattern = $false
)
<#======================================================================================
          File Name : DomainPurge.ps1
    Original Author : Kenneth C. Mazie 
                    : 
        Description : Removes any systems in Active Directory who have not connected
                    :   in over 30 days.
                    : 
              Notes : No local log generated.   Emails results to recipient list.
                    :   Number of days in purge window is adjustable via variable.
                    :   Add systems to exclude to XML file in same folder as script.
                    : Create a scheduled task to run daily.
                    :
          Arguments : Normal operation is with no command line options. 
                    : -console $true    = Displays status output to console - defaults to $false
                    : -debug $true      = Handles output normally but blocks anything from being actively deleted.
                    : -fullreport $true = Emails the entire run report rather than just what was found. - defaults to $false
                    : -nopurge $true    = Disable all deletes - default to $false    
                    : -usepattern $true = Read pattern from config file and ignore matches. - defaults to false (forced on below)
                    : 
           Warnings : Don't run if you don't want PC's deleted from AD
                    :   
              Legal : Public Domain. Modify and redistribute freely. No rights reserved.
                    :   SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF 
                    :   ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.
                    :
            Credits : Code snippets and/or ideas came from many sources including but 
                    :   not limited to the following: Internet - various
                    :
     Last Update by : Kenneth C. Mazie 
    Version History : v1.0 - 05-16-13 - Original 
     Change History : v1.1 - 05-01-15 - Added reporting option & ESX filter
                    : v2.0 - 10-30-15 - Changed the way html is created. Retooled to run 
                   	:    daily and check date to determine whether to run.
                    : v2.1 - 02-01-16 - Switched to ADO delete due to extra objects on 
                    :    systems in AD.
                    : v3.00 - 10-31-17 - Added XML config file.  Changed report info.  Added credentials.
                    : v3.10 - 11-10-17 - minor output edit.
                    : v4.00 - 12-08-17 - Complete rework. Now checks each system daily. 
                    : v4.10 - 01-19-18 - Fixed output bug. Added full report option. Removed force run option.
                    : v4.20 - 02-14-18 - Added option to ignore based on a pattern.                    
					: v4.22 - 03-03-18 - Minor notation tweak for PS library upload
                    :
                    : #>
    $CurrentVersion = 4.22            <#
                    :    
=======================================================================================#>
<#PSScriptInfo
.VERSION 4.22
.AUTHOR Kenneth C. Mazie (kcmjr AT kcmjr.com)
.GUID 6d8d1d4d-0b4f-49dd-9f86-9841d9e92981
.DESCRIPTION 
 Removes any systems in Active Directory who have not connected in over 30 days.
#> 
# Requires -version 4.0
Clear-Host

If ($Debug){$Script:Debug = $True}
If ($Console){$Script:Console = $True}
If ($FullReport){$Script:FullReport = $true}
If ($NoPurge){$Script:NoPurge = $True}
#If ($UsePattern){
$Script:UsePattern = $True  #--[ forced to true ]--
#}

#-------------------------------[ Begin ]--------------------------------------
$ErrorActionPreference = "SilentlyContinue"
$ExclusionList = ""
$Computer = $Env:ComputerName
$ScriptName = ($MyInvocation.MyCommand.Name).split(".")[0] 
$Script:LogFile = $PSScriptRoot+"\"+$ScriptName+"_{0:MM-dd-yyyy_HHmmss}.log" -f (Get-Date)
$Script:ConfigFile = "$PSScriptRoot\$ScriptName.xml"  

#-----------------------------[ Functions ]------------------------------------
Function SendEmail {
    $email = New-Object System.Net.Mail.MailMessage
    $email.From = $Script:EmailFrom
    $email.IsBodyHtml = $Script:EmailHTML
    If ($Script:Debug){
        $email.To.Add($Script:DebugEmail)
    }Else{
        $email.To.Add($Script:EmailTo)
    }
    $email.Subject = $Script:Subject
    $email.Body = $Script:ReportBody 
    $smtp = new-object Net.Mail.SmtpClient($Script:SmtpServer)
    $smtp.Send($email)
    If ($Script:Console){Write-Host "`nStatus email has been sent" -ForegroundColor green}
}

Function LoadConfig {  #--[ Read and load configuration file ]------------------
    If (!(Test-Path $Script:ConfigFile)){       #--[ Error out if configuration file doesn't exist ]--
        Write-Host "---------------------------------------------" -ForegroundColor Red
        Write-Host "--[ MISSING CONFIG FILE.  Script aborted. ]--" -ForegroundColor Red
        Write-Host "---------------------------------------------" -ForegroundColor Red
        break
    }Else{
        [xml]$Script:Configuration = Get-Content $Script:ConfigFile       
        $Script:ReportName = $Script:Configuration.Settings.General.ReportName
        $Script:DebugTarget = $Script:Configuration.Settings.General.DebugTarget 
        $Script:DebugEmail = $Script:Configuration.Settings.Email.DebugEmail 
        $Script:ExclusionList = ($Script:Configuration.Settings.General.Exclusions).Split(",")
        $Script:Days = $Script:Configuration.Settings.General.Days
        $Script:Subject = $Script:Configuration.Settings.Email.Subject
        $Script:EmailTo = $Script:Configuration.Settings.Email.To
        $Script:EmailFrom = $Script:Configuration.Settings.Email.From
        $Script:EmailHTML = $Script:Configuration.Settings.Email.HTML
        $Script:SmtpServer = $Script:Configuration.Settings.Email.SmtpServer
        $Script:UserName = $Script:Configuration.Settings.Credentials.Username
        $Script:EncryptedPW = $Script:Configuration.Settings.Credentials.Password
        $Script:Base64String = $Script:Configuration.Settings.Credentials.Key   
        $ByteArray = [System.Convert]::FromBase64String($Script:Base64String);
        $Script:Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Script:UserName, ($Script:EncryptedPW | ConvertTo-SecureString -Key $ByteArray)
        $Script:Password = $Script:Credential.GetNetworkCredential().Password
    }
}
#-------------------------------------------------------------------------------	
LoadConfig 

#--[ HashTables ]--
$MonthDays = @{
"January" = "31";
"February" = "28";
"March" = "31";
"April" = "30";
"May" = "31";
"June" = "30";
"July" = "31";
"August" = "31";
"September" = "30";
"October" = "31";
"November" = "30";
"December" = "31"
}

#--[ Date Processing ]----------------------------------------------------------
$CurrentDate = Get-Date

$ThisMonth = @()
$ThisMonth += (Get-Date -Format MMMM)                                   #--[ This month text name ]--
$ThisMonth += $CurrentDate.Month                                        #--[ This month number ]--
$ThisMonth += $MonthDays.($ThisMonth[0])
                
$NextMonth = @()
If ($ThisMonth[1] -eq 12){
    $NextMonth += (Get-Date -Month 1).tostring("MMMM")                  #--[ Force values for january if it is December now ]--
	$NextMonth += "1"
    $NextMonth += "31"
}Else{
    $NextMonth += (Get-Date -Month ($ThisMonth[1]+1) ).tostring("MMMM")
    $NextMonth += $CurrentDate.Month+1
    $NextMonth += $MonthDays.($NextMonth[0])
}

$DaysOut = ""
$DaysOut = (Get-Date).AddDays(-([int]$Script:DaysOut))                  #--[ Date 30 days from today or whatever value was loaded from config ]--
$DaysOut = ($DaysOut).ToString("MM/dd/yyy") 

If ($Script:Debug){
    If ($Script:Console){
        Write-Host `n"--[ "$Script:ReportName" ]---" -ForegroundColor Cyan -NoNewline
        Write-Host " DEBUG MODE " -ForegroundColor Yellow -NoNewline
        Write-Host "----------------------"`n -ForegroundColor Cyan 
    }
}Else{
    If ($Script:Console){Write-Host `n"--[ "$Script:ReportName" ]--------------------------------------"`n -ForegroundColor Cyan }
}

If ($Script:Console){Write-Host "Now              :"$CurrentDate -ForegroundColor Cyan }
If ($Script:Console){Write-Host 'This Month       :'$ThisMonth[0] '('$ThisMonth[1]')' -ForegroundColor Cyan }
If ($Script:Console){Write-Host 'Day of Month     :'$CurrentDate.Day -ForegroundColor Cyan }
If ($Script:Console){Write-Host 'Days this month  :'$ThisMonth[2]`n -ForegroundColor Cyan }
If ($Script:Console){Write-Host 'Next Month       :'$NextMonth[0] '('$NextMonth[1]')' -ForegroundColor Cyan }
If ($Script:Console){Write-Host 'Days next Month  :'$NextMonth[2]`n -ForegroundColor Cyan }
If ($Script:Console){Write-Host 'Purge window     :'$Script:Days' Days ' -ForegroundColor Cyan }
If ($Script:Console){Write-Host 'Exclusion filter :'$Script:ExclusionList`n -ForegroundColor Cyan }

#--[ Main Process ]------------------------------------------------------------- 
$Script:Action = "stop"
If ($Debug){
    $TargetGroup = Get-ADComputer -Properties Name, lastLogonDate, operatingsystem -Credential $Script:Credential -Filter {name -like $Script:DebugTarget -an operatingSystem -notlike "*server*"} | sort Name 
}Else{
    $TargetGroup = Get-ADComputer -Properties Name, lastLogonDate, operatingsystem -Credential $Script:Credential -Filter {lastLogonDate -lt $DaysOut} | sort Name 
}

#--[ Add header to html log file ]--
$Script:FontDarkCyan = '<p style="display:inline;font-family:Calibri;size:7pt;color:#008B8B;margin-top:0px;margin-bottom:0px;">'
$Script:FontBlack = '<p style="display:inline;font-family:Calibri;size:7pt;color:#000000;margin-top:0px;margin-bottom:0px;">'
$Script:FontRed = '<p style="display:inline;font-family:Calibri;size:7pt;color:#ff0000;margin-top:0px;margin-bottom:0px;">'
$Script:FontMaroon = '<p style="display:inline;font-family:Calibri;size:7pt;color:#990000;margin-top:0px;margin-bottom:0px;">'
$Script:FontGreen = '<p style="display:inline;font-family:Calibri;size:7pt;color:#00ff00;margin-top:0px;margin-bottom:0px;">'
$Script:FontDarkGreen = '<p style="display:inline;font-family:Calibri;size:7pt;color:#008b00;margin-top:0px;margin-bottom:0px;">'
$Script:FontYellow = '<p style="display:inline;font-family:Calibri;size:7pt;color:#ff9900;margin-top:0px;margin-bottom:0px;">'
$Script:FontOrange = '<p style="display:inline;font-family:Calibri;size:7pt;color:#ff6600;margin-top:0px;margin-bottom:0px;">'
$Script:FontDimGray = '<p style="display:inline;font-family:Calibri;size:7pt;color:#696969;margin-top:0px;margin-bottom:0px;">'

$Script:ReportBody = @() 
$Script:ReportBody += '
<style type="text/css">
    table.myTable { border:5px solid black;border-collapse:collapse; }
    table.myTable td { border:2px solid black;padding:5px}
    table.myTable th { border:2px solid black;padding:5px;background: #949494 }
    table.bottomBorder { border-collapse:collapse; }
    table.bottomBorder td, table.bottomBorder th { border-bottom:1px dotted black;padding:5px; }
    tr.noBorder td {border: 0; }
</style>
<table class="myTable">
<tr class="noBorder"><td colspan=4><center><h1>- '+$Script:ReportName+' -</h1></td></tr>
<tr class="noBorder"><td colspan=4><center>Computers with SecureChannel refresh older than '+$Days+' days will be deleted from the domain.</td></tr>
<tr class="noBorder"><td colspan=4><center>Computers within 5 days of deletion are listed as a warning of their impending deletion.<br></td></tr>
<tr class="noBorder"><td colspan=4><center>Current exclusion filter (from config file) includes the following strings: "'+$Script:ExclusionList+'"
<tr class="noBorder"><td colspan=4><center>Today is '+(Get-Date -Format MM/dd/yyyy)+'</td></tr>
'

If ($Script:Debug){
    $Script:ReportBody += '<tr class="noBorder"><td colspan=4><center><strong><font color=red>Script running in DEBUGGING mode...</strong></font></td></tr>'
}
If ($Script:NoPurge){
    $Script:ReportBody += '<tr class="noBorder"><td colspan=4><font color=darkgreen><center>Script running in NOPURGE mode...  NO DELETES WILL BE EXECUTED...</font></td></tr>'
}

$Script:ReportBody += '<tr><th>Target System</th><th>Last Secure Channel Update</th><th>Action</th><th>Delete Verification</th></tr>'   #--[ Report Header ]--------

foreach ($Target in $TargetGroup){
    If ($Script:FullReport){
        $Script:ReportFlag = $True
    }Else{
        $Script:ReportFlag = $False
    }
    $ExcludeFlag = $false
    $Script:ExclusionList | foreach{
        if ($Target.Name -match $_){$ExcludeFlag = $true}
    }  
    $DaysOld = (New-TimeSpan $Target.lastLogonDate $(Get-Date)).Days                    #--[ Days since target last secure channel refresh ]--
    $KillDate = (Get-Date ($CurrentDate.AddDays(30-$DaysOld)) -Format "MM/dd/yyyy")
    $DaysLeft = ($Script:Days)-($DaysOld)
    
    If (($DaysOld -ge 25) -and (!$ExcludeFlag)){$Script:ReportFlag = $True}
     
    If ($ReportFlag){        
        #--[ Generate HTML new row ]------------------------------------------------
        $BGColor = "#dfdfdf"    													#--[ Grey default cell background ]--
        $FGColor = "#000000"    													#--[ Black default cell foreground ]--
        $Script:RowData = '<tr>'    											   	#--[ Start table row ]--
   	    $Script:RowData += '<td bgcolor=' + $BGColor + '>'+$Script:FontDarkCyan+$Target.Name+"</td>"
        $Script:RowData += '<td bgcolor=' + $BGColor + '>'+$Script:FontDarkCyan+$Target.lastLogonDate + "&nbsp&nbsp&nbsp&nbsp("+(New-TimeSpan $Target.lastLogonDate $(Get-Date)).Days +"&nbspDays) </td>"
    }

    If ($Script:Console){
        Write-Host "--[ Current Target ="$Target.Name"]-----------------" -ForegroundColor Magenta 
        Write-Host "-- Date of last secure channel refresh       =" $Target.lastLogonDate -ForegroundColor Yellow
        Write-Host "-- Days since last secure channel refresh    =" $DaysOld -ForegroundColor Yellow
    }

    If ($Script:Debug){        
   	    Write-Host  "-- Extended Information from Active Directory" -ForegroundColor Cyan
        $TargetInfo = Get-ADComputer -Identity $Target -Credential $Script:Credential -ErrorAction "silentlycontinue" 		    	
        $TargetInfo
    }

    If ($DaysOld -ge 25){
        $Script:Action = "warn"
        If ($Script:Console){Write-Host "-- Days until deletion from Active Directory =" $DaysLeft -ForegroundColor Yellow}
    }
            
    If($DaysOld -ge 30){
        $Script:Action = "run"
        $DaysLeft = 0
    }
            
    If ($ExcludeFlag){
        If ($Script:Console){Write-Host "-- EXEMPT from AD purge. --" -ForegroundColor Magenta }
        If ($ReportFlag){
            $Script:RowData += '<td bgcolor='+$BGColor+'><center>'+$Script:FontDarkGreen+'-- EXEMPT from AD deletion --</center></td>'
	        $Script:RowData += '<td bgcolor='+$BGColor+'>'+$Script:FontDarkGreen+'</td>'
        }
    }else{    
        If (($Target.Name.SubString(0,1) -eq "w") -and ($Target.Name.SubString(1,1) -match "^[-]?[0-9.]+$") -and ($_.operatingsystem -NotLike "*server*") -and $Script:UsePattern){ #--[ Bypass according to a pattern ]--
            If ($Script:Console){Write-Host "-- Pattern-select enabled.  Pattern matched.  IGNORING --" -ForegroundColor green}
            If ($ReportFlag){
                $Script:RowData += '<td bgcolor='+$BGColor+'><center><font color=#A9A9A9>IGNORING</td><td bgcolor='+$BGColor+'><font color=#A9A9A9>Pattern bypass in effect</center></font></td>'
            } 
        }Else{
  	        If ($Script:Action -eq "warn"){
     	        If ($Script:Console){Write-Host  "-- SCHEDULED to be deleted from Active Directory --" -ForegroundColor Red}
                If ($Script:ReportFlag){
                    $Script:RowData += '<td bgcolor='+$BGColor+'>'+$Script:FontOrange+'SCHEDULED to be deleted in '+$DaysLeft+' days on</td>'
                    $Script:RowData += '<td bgcolor='+$BGColor+'><center>'+$Script:FontOrange+$KillDate+'</center></td>'
                }   
            }Else{
          	    If ($DaysOld -ge $Days){ 
                    If ($Script:Console){Write-Host "-- DELETING"$target.name"From Active Directory -- " -ForegroundColor Red}
           	        If ($ReportFlag){$Script:RowData += '<td bgcolor='+$BGColor+'><center>'+$Script:FontRed+'--- DELETING From AD ---</center></td>'}
                    If (!$Script:NoPurge){
                        Get-ADComputer -Identity $Target -Credential $Script:Credential | Remove-ADObject -Recursive -Credential $Script:Credential -Confirm:$false  
                        #Remove-ADComputer -identity $Target -Credential $Script:Credential         #--[ Alternate method ]--
                        #Set-ADComputer -Disabled $false		    								#--[ Can be used to disable instead of delete.
                        #--[ Verification ]---------------------------------------------------------
                        Try{                
                            Get-ADComputer -Identity $Target -Credential $Script:Credential -ErrorAction "silentlycontinue"
                            If ($Script:Console){Write-Host "-- Verification FAILED --"$Target.Name -ForegroundColor Red}
                            If ($ReportFlag){$Script:RowData += '<td bgcolor='+$BGColor+'>'+$Script:FontRed+'-- Verification FAILED --</td>'}
                        }Catch{    
                   	        If ($Script:Console){Write-Host "-- Verified DELETED From Active Directory -- "$Target.Name -ForegroundColor green}
                            If ($Script:ReportFlag){$Script:RowData += '<td bgcolor='+$BGColor+'><center>'+$Script:FontDarkGreen+'-- VERIFIED --</center></td>'}
                        } 
                    }Else{
                        If ($Script:Console){Write-Host "-- No Action Taken.   NOPURGE Enabled -- " -ForegroundColor green}
                        If ($Script:ReportFlag){$Script:RowData += '<td bgcolor='+$BGColor+'><center>'+$Script:FontDarkGreen+'-- NOPURGE Enabled --</center></td>'}
                    }    
                }Else{
                  	If ($Script:Console){Write-Host "-- No Action Taken.  Within"$Script:Days" day safety window." -ForegroundColor green}
                    If ($Script:ReportFlag){
                        $Script:RowData += '<td bgcolor='+$BGColor+'>&nbsp;</td><td bgcolor='+$BGColor+'>&nbsp;</td>'
                    }
                }  
            }
        }
	
  	    If ($Script:Console){Write-Host "`n-----------------------------------------------------`n" -ForegroundColor yellow}
        If ($ReportFlag){
            $Script:RowData += '</tr>'
            $Script:ReportBody += $Script:RowData
        }
        $Script:Action = "run"
    }
    $Script:ReportFlag = $False
}

$Script:ReportBody += '<tr class="noBorder"><td colspan=8><font size=2 color=#909090><br>Script "'+$MyInvocation.MyCommand.Name+'" executed from server "'+$env:computername+'".</td></tr>'
$Script:ReportBody += "</table><br>"

#--[ Send The Email ]--   
SendEmail

If ($Script:Console){Write-Host "`n--- COMPLETED ---`n" -ForegroundColor Red }

 

<#--[ Sample XML config file ]--------------------------------------------------

<!-- Settings & Configuration File -->
<Settings>
	<General>
		<ReportName>Domain Stale Computer Purge</ReportName>
		<DebugTarget>mypc</DebugTarget>
		<Exclusions>jumpbox,test,-x-,dc</Exclusions>
		<Domain>mydomain.com</Domain>
        <Days>30</Days>
	</General>
	<Email>
		<From>WeeklyReports@mydomain.com</From>
		<To>me@mydomain.com</To>
		<DebugEmail>degug@mydomain.com</DebugEmail>
		<Subject>Domain Stale Computer Purge</Subject>
		<HTML>$true</HTML>
		<SmtpServer>10.10.15.15</SmtpServer>
	</Email>
	<Credentials>
		<UserName>mydomain\serviceuser</UserName>
		<Password>76492d111xAQA0AEcAAGEAYQB6743f042GIATgBWnHbuTeJ8mIaADANgA0AGEAMAAwADQAZgBiAGMAYQBhADQ3b1DUAYQA2AGQAZAA2ADQHoAe341cAYAzaAB1AAYwBkADYAZQBmAGQAOAA0ADEANgBiADAANwBkADEANAA4AGQAZgA3ADIAYQAwADYAZAA3AGUAZgBkAGYAZAA=</Password>
		<Key>kdhCh7HXN0IObie67L6/AWnHCA6FEAPQA9AHwAYwyAWnHbuTeJ8mIObivLO+Eyj27IXN0eJ7IbuTE=</Key>
	</Credentials>
</Settings>	

#>
