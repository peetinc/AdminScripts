<#
# Script Name:              Install-Splashtop-Upgrade-Install.ps1
# Script Author:            Peet McKinney @ Artichoke Consulting

# Changelog                 
2019.11.19                 Initial Checkin                 PJM
2021.04.30                 Clean up, add direct download version check. add controls for ReqPassword 8 and UnLockUI 0 and AutoStart 1 PJM


This script will download and deploy or upgrade Splashtop Streamer based on version and download URL defined in script.

Syncro Script Variables:

Requires $Splashtop_DeployCode (Create Customer Custom Field "Text Field" for each DeployCode to be saved with each customer and map to the variable)
Requires $Splashtop_ConnectURI_Syncro (Create a "Web link" Custom Asset Field and map to the variable)
Requires $Splashtop_Name_Syncro (Create a "Text Field" Custom Asset Field and map to the variable)

#>

Import-Module $env:SyncroModule

####################################
## Install (or Upgrade) Splashtop ##
## Enforce specific settings      ##
####################################

# Variables MUST_SET 
$DownloadSource = "https://my.splashtop.com/csrs/win" #Do not change, the current version is pulled from the redirected URL
$ProgramName="Splashtop Streamer" #Whatever you want to call the product in Write-Output
$Installer = "$env:TEMP\splashtop_streamer.exe" #Where you'd like installer saved
$MyCSRTeamName = "Your Deployment Team Name" #Found in Status window of Deployed Streamer under "Computer Deployed by"
$STS_Service = "SplashtopRemoteService"

# SyncroMSP variables
$SyncroSubdomain = "YourSubdomain" #If you don't know this don't use this script
$Splashtop_ConnectURI_AssetField = "Field Name For SplashtopConnectURI" #Create a "Web link" Custom Asset Field and provide name here
$SplashtopName_AssetField = "Field Name for Splashtop Computer Name"#Create a "Test field" Custom Asset Field and provide name here

# Variables for Settings
$IdleSessionTimeout_setting = "60" #You'd better have a timout in minutes
$ReqPassword_setting = "8" #0 = No additional password, 4 = Security code (can't set security code through here), 8 = Windows login
$UnLockUI_setting = "0" #0 = Lock if Standard User, 1 = Splashtop admin lock, 2 = No lock
$AutoStart_setting = "1" #Ensures Autostart enabled
$NoTrayIcon_setting = "0" # 0 = Not hidden 1 = Hidden

# Make sure Syncro provides a Deploy Code
if ($Splashtop_DeployCode -eq "" -or $Splashtop_DeployCode -eq $null) {
  Write-Output "DeployCode"
  Write-Output "Deploy Code not set. Falling back to Generic Deploy Code ..."
  $Splashtop_DeployCode = "123456789012345678" #Your Team's Genereic Deploy Code
  Write-Output "Deploy code is $Splashtop_DeployCode"
  } else {
  Write-Output "Deploy code is $Splashtop_DeployCode"
}

##Functions    
# Function to download Splashtop Streamer
Function Get-Installer{
  Write-Output "Downloading $ProgramName ..."
  if (Get-Command 'Invoke-Webrequest'){
    Invoke-WebRequest $DownloadSource -OutFile $Installer
  } else {
    $WebClient = New-Object System.Net.WebClient
    $webclient.DownloadFile($DownloadSource, $Installer)
  }
}

# Function to upgrade Program
Function Install-Upgrade{
  Get-Installer
  Write-Output "Upgrading $ProgramName ..."
  Start-Process -FilePath $Installer -ArgumentList "prevercheck /s /i hidewindow=1" -Wait
  Start-Sleep -s 3
  Write-Output "Deleting $Installer."
  Remove-Item -path $Installer
}
    
# Function to install Program
Function Install-New{
  Get-Installer
  Write-Output "Installing $ProgramName ..."
  Start-Process -FilePath $Installer -ArgumentList "prevercheck /s /i dcode=DeployCode,confirm_d=0,hidewindow=1" -Wait
  Start-Sleep -s 3
  Write-Output "Deleting $Installer."
  Remove-Item -path $Installer
}

# Function to redeploy Program
Function Install-Redeploy{
  Get-Installer
  Write-Output "Redeploying $ProgramName ..."
  Start-Process -FilePath $Installer -ArgumentList "prevercheck /s /i dcode=DeployCode,confirm_d=0,hidewindow=1" -Wait
  Start-Sleep -s 3
  Write-Output "Deleting $Installer."
  Remove-Item -path $Installer
}

# Function install-upgrade check
Function Install-Check{
  Write-Output "Checking installed version of $ProgramName ..."
  $InstalledVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").Version
  $CurrentVersion = $(invoke-webrequest -uri $DownloadSource -Method Get -MaximumRedirection 0 -UseBasicParsing -ErrorAction SilentlyContinue).Headers.location -match '\d+(\.\d+)+' -match '\d+(\.\d+)+'
  $CurrentVersion = $Matches[0]
  $CSRTeamName = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").CSRSTeamName
  if ($InstalledVersion -ne $nul -and $InstalledVersion -lt $CurrentVersion){
    Write-Output "$ProgramName v.$CurrentVersion is available."
    Write-Output "$ProgramName v.$InstalledVersion is installed."
    Write-Output "Upgrade required."
    $global:InstallStatus = "NeedsUpgrade"
  }
  if ($InstalledVersion -eq "" -or $InstalledVersion -eq $nul){
    $global:InstallStatus = "NeedsInstall"
     Write-Output "$ProgramName InstallStatus: $InstallStatus."    
  }
  if ($MyCSRTeamName -ne $CSRTeamName){
    $InstallStatus = "ReDeploy"
    Write-Output "CSRTeamName is not $MyCSRTeamName"
    Write-Output "$ProgramName InstallStatus: $InstallStatus."
    Write-Output "Reinstalling $ProgramName With $Splashtop_DeployCode"
  }
  if ($InstalledVersion -eq $CurrentVersion){
    $global:InstallStatus = "UpToDate"
    Write-Output "$ProgramName InstallStatus: $InstallStatus."
  }
}

# Function update Splashtop ConnectURI in Syncro
Function Update-ConnectURI{
  $STUUID = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").SUUID
  $Splashtop_ConnectURI_Local = "st-business://com.splashtop.business?uuid=$STUUID"
  if ($Splashtop_ConnectURI_Local -ne $Splashtop_ConnectURI_Syncro ) {
    Write-Output "Updating $ProgramName URI for $CloudComputerName ..."
    Write-Output "From $Splashtop_ConnectURI_Syncro"
    Write-Output "To $Splashtop_ConnectURI_Local"
    Set-Asset-Field -Subdomain "$SyncroSubdomain" -Name "$Splashtop_ConnectURI_AssetField" -Value "$Splashtop_ConnectURI_Local"
    } else {
    Write-Output "$ProgramName URI`: $Splashtop_ConnectURI_Syncro"
    }
}

#Function to update Splashtop Names to Hostname
Function Update-SplashtopName{
  $CloudComputerName = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").CloudComputerName
  if ($CloudComputerName -ne $env:ComputerName){
    Write-Output "Updating $ProgramName CloudComputerName from $CloudComputerName to $env:ComputerName."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Name "CloudComputerName" -Value "$env:ComputerName" -Force | Out-Null
    $global:RestartSTS = $true
    $CloudComputerName = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").CloudComputerName
  }
  if ($Splashtop_Name_Syncro -ne $CloudComputerName){
    Write-Host "Updating Splashtop_Name from $Splashtop_Name_Syncro to $CloudComputerName."
    Set-Asset-Field -Subdomain "$SyncroSubdomain" -Name "$SplashtopName_AssetField" -Value "$CloudComputerName"
    }
  Write-Output "$ProgramName Computer Name: $CloudComputerName"
}

#Function to update Splashtop IdleSessionTimeout
Function Update-IdleSessionTimeout{
  $IdleSessionTimeout = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").IdleSessionTimeout
  if ($IdleSessionTimeout_setting -ne $IdleSessionTimeout){
    Write-Output "Updating $ProgramName IdleSessionTimeout from $IdleSessionTimeout to $IdleSessionTimeout_setting."
    New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Name "IdleSessionTimeout" -Value "$IdleSessionTimeout_setting" -PropertyType DWORD -Force | Out-Null
    $global:RestartSTS = $true
  } 
}

#Function to update Splashtop ReqPassword
Function Update-ReqPassword{
  $ReqPassword = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").ReqPassword
  if ($ReqPassword_setting -ne $ReqPassword){
    Write-Output "Updating $ProgramName ReqPassword from $ReqPassword to $ReqPassword_setting."
    New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Name "ReqPassword" -Value "$ReqPassword_setting" -PropertyType DWORD -Force | Out-Null
    $global:RestartSTS = $true
  } 
}

#Function to update Splashtop UnLockUI
Function Update-UnLockUI{
  $UnLockUI = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").UnLockUI
  if ($UnLockUI_setting -ne $UnLockUI){
    Write-Output "Updating $ProgramName UnLockUI from $UnLockUI to $UnLockUI_setting."
    New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Name "UnLockUI" -Value "$UnLockUI_setting" -PropertyType DWORD -Force | Out-Null
    $global:RestartSTS = $true
  } 
}

#Function to update Splashtop AutoStart
Function Update-AutoStart{
  $AutoStart = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").AutoStart
  if ($AutoStart_setting -ne $AutoStart){
    Write-Output "Updating $ProgramName AutoStart from $AutoStart to $AutoStart_setting."
    New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Name "AutoStart" -Value "$AutoStart_setting" -PropertyType DWORD -Force | Out-Null
    $global:RestartSTS = $true
  } 
}

#Function to update Splashtop NoTrayIcon
Function Update-NoTrayIcon{
  $NoTrayIcon = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").NoTrayIcon
  if ($NoTrayIcon_setting -ne $NoTrayIcon){
    Write-Output "Updating $ProgramName NoTrayIcon from $NoTrayIcon to $NoTrayIcon_setting."
    New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Name "NoTrayIcon" -Value "$NoTrayIcon_setting" -PropertyType DWORD -Force | Out-Null
    $global:RestartSTS = $true
  } 
}

#Function to Restart Splashtop Streamer if necessary
Function Restart-Streamer{
  if ($RestartSTS) {
    Write-Output " "
    Write-Output "Stopping $STS_Service"
    net stop $STS_Service
    Write-Output "Starting $STS_Service"
    net start $STS_Service
  }
}

	
##Main
# Test if $InstallStatus is NeedsUpgrade, NeedsInstall or UpToDate
Install-Check
if ($InstallStatus -eq "NeedsUpgrade") {
  Install-Upgrade
  Install-Check
}
if ($InstallStatus -eq "NeedsInstall") {
  Install-New
  Install-Check
}
if ($InstallStatus -eq "ReDeploy") {
  Install-ReDeploy
  Install-Check
}
if ($InstallStatus -eq "UpToDate") {
  Update-SplashtopName
  Update-ConnectURI
  Update-IdleSessionTimeout
  Update-ReqPassword
  Update-UnLockUI
  Update-AutoStart
  Update-NoTrayIcon
  Restart-Streamer
  Exit 0
  }else{
  Exit 1
} 