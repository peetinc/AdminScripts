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

## Variables
#  MUST_SET variables
$MyCSRTeamName = "Your Deployment Team Name" #Found in Status window of Deployed Streamer under "Computer Deployed by"
$Generic_DeployCode = "123456789012345678" #A Generic Deploy Code for you Team as fallback

# SyncroMSP variables
$Splashtop_ConnectURI_AssetField = "Field Name For SplashtopConnectURI" #Create a "Web link" Custom Asset Field and provide name here
$SplashtopName_AssetField = "Field Name for Splashtop Computer Name"#Create a "Test field" Custom Asset Field and provide name here

# STS Settings variables 
$IdleSessionTimeout_setting = "60" #You'd better have a timout in minutes
$ReqPassword_setting = "8" #0 = No additional password, 4 = Security code (can't set security code through here), 8 = Windows login
$UnLockUI_setting = "0" #0 = Lock if Standard User, 1 = Splashtop admin lock, 2 = No lock
$AutoStart_setting = "1" #Ensures Autostart enabled
$NoTrayIcon_setting = "0" # 0 = Not hidden 1 = Hidden

# "Static" variables: Here incase they need an update, Think before changing.
$DownloadSource = "https://my.splashtop.com/csrs/win" #Do not change, the current version is pulled from the redirected URL
$Installer = "$env:TEMP\splashtop_streamer.exe" #Where you'd like installer saved
$ProgramName="Splashtop Streamer" #Whatever you want to call the product in Write-Output
$STS_Service = "SplashtopRemoteService"

##Functions
#Function Test for presense of Registry Value
function Test-RegistryValue {
  param (
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Path,
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Value
  )
  try{
    Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
    return $true
  }
  catch{
    return $false
  }
}
# Function install-upgrade check
Function Install-Check{
  if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\"){
    if (Test-RegistryValue "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Value "Version"){
      $InstalledVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").Version
    }
    if (Test-RegistryValue "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Value "CSRSTeamName"){
      $CSRTeamName = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").CSRSTeamName
    }
  }
  $CurrentVersion = $(invoke-webrequest -uri "https://my.splashtop.com/csrs/win" -Method Get -MaximumRedirection 0 -UseBasicParsing -ErrorAction SilentlyContinue).Headers.location -match '\d+(\.\d+)+' | Out-Null
  $CurrentVersion = $Matches[0]
  
  if ($InstalledVersion -and $InstalledVersion -lt $CurrentVersion){
    Write-Output "$ProgramName v.$CurrentVersion is available."
    Write-Output "$ProgramName v.$InstalledVersion is installed."
    Write-Output "Upgrade required."
    $global:InstallStatus = "NeedsUpgrade"
  }
  if (!($InstalledVersion)){
    $global:InstallStatus = "NeedsInstall"
    Write-Output "$ProgramName InstallStatus: $InstallStatus."    
  }
    if (($CSRTeamName) -and ($MyCSRTeamName -ne $CSRTeamName)){
    $InstallStatus = "ReDeploy"
    Write-Output "Warning: CSRTeamName is not $MyCSRTeamName"
    Write-Output "$ProgramName InstallStatus: $InstallStatus."
    Write-Output "Redeploying $ProgramName With $Splashtop_DeployCode"
  }
  if ($InstalledVersion -ge $CurrentVersion){
    $global:InstallStatus = "UpToDate"
    Write-Output "$ProgramName InstallStatus: $InstallStatus."
  }
  if (!($CurrentVersion)){
    $global:InstallStatus = "MissingCurrentVersion"
    Write-Output "Warning: CurrentVersion not found. Please Reevaluate  `$CurrentVersion definition."
  }
}

# Function to ensure $Splashtop_DeployCode is set 
Function Check-DeployCode{
  if (!($Splashtop_DeployCode)) {
    Write-Output "Deploy Code not set. Falling back to Generic Deploy Code ..."
    global:Splashtop_DeployCode = "$Generic_DeployCode"
    Write-Output "$ProgramName DeployCode: $Splashtop_DeployCode"
  } else {
    Write-Output "$ProgramName DeployCode: $Splashtop_DeployCode"
  }
  if (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\"){
    if (Test-RegistryValue "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\" -Value "DCode"){
      $DCode=$(Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").DCode
    }
  }
  if (($DCode) -and ($Splashtop_DeployCode -ne $DCode)){
    Write-Output "Warning: DeployCode `($DCode`) does not match provided DeployCode `($Splashtop_DeployCode`)"
    # Uncomment the next lines if you'd like to force a ReDeploy in this situation
    #$global:InstallStatus = "ReDeploy"
    #Write-Output "$ProgramName InstallStatus: $InstallStatus."
    #Write-Output "Redeploying $ProgramName With $Splashtop_DeployCode"
  }
} 

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
  Remove-Variable -Scope Global -name InstallStatus
}
    
# Function to install Program
Function Install-Deploy{
  Get-Installer
  Write-Output "Installing $ProgramName ..."
  Start-Process -FilePath $Installer -ArgumentList "prevercheck /s /i dcode=$Splashtop_DeployCode,confirm_d=0,hidewindow=1" -Wait
  Start-Sleep -s 3
  Write-Output "Deleting $Installer."
  Remove-Item -path $Installer
  Remove-Variable -Scope Global -name InstallStatus
}

# Function to redeploy Program
Function Install-Redeploy{
  Get-Installer
  #Uninstallation is unnecessary, but it's nice to keep this code if needed:
  #$STS_Install = $(get-wmiobject -class Win32_Product -filter "Name = 'Splashtop Streamer'")
  #$STS_UUID=$STS_Install.IdentifyingNumber 
  #if ($STS_UUID) {
  #  Write-Output "Uninstalling $ProgramName ..."
  #  Start-Process msiexec.exe -ArgumentList "/x $STS_UUID.IdentifyingNumber /qn" -Wait
  #  Write-Output "$ProgramName uninstalled ..."
  #}
  Write-Output "Redeploying $ProgramName ..."
  Start-Process -FilePath $Installer -ArgumentList "prevercheck /s /i dcode=$Splashtop_DeployCode,confirm_d=0,hidewindow=1" -Wait
  Start-Sleep -s 3
  Write-Output "Deleting $Installer."
  Remove-Item -path $Installer
  Remove-Variable -Scope Global -name InstallStatus
}

# Function update Splashtop ConnectURI in Syncro
Function Update-ConnectURI{
  $STUUID = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Splashtop Inc.\Splashtop Remote Server\").SUUID 
  $Splashtop_ConnectURI_Local = "st-business://com.splashtop.business?uuid=$STUUID"
  if ($Splashtop_ConnectURI_Local -ne $Splashtop_ConnectURI_Syncro ) {
    Write-Output "Updating $ProgramName URI for $CloudComputerName ..."
    Write-Output "From $Splashtop_ConnectURI_Syncro"
    Write-Output "To $Splashtop_ConnectURI_Local"
    Set-Asset-Field -Name "$Splashtop_ConnectURI_AssetField" -Value "$Splashtop_ConnectURI_Local"
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
    Set-Asset-Field -Name "$SplashtopName_AssetField" -Value "$CloudComputerName"
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
Install-Check
Check-DeployCode
if ($InstallStatus -eq "NeedsUpgrade") {
  Install-Upgrade
  Install-Check
}
if ($InstallStatus -eq "NeedsInstall") {
  Install-Deploy
  Install-Check
}
if ($InstallStatus -eq "ReDeploy") {
  Install-ReDeploy
  Install-Check
}
if ($InstallStatus -eq "UpToDate" -or $InstallStatus -eq "MissingCurrentVersion") {
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