 <#
# Script Name:              Enforce-ChocoManaged-jre8.ps1
# Script Author:            Peet McKinney @ Artichoke Consulting

# Changelog                 
2021.05.06              Initial Checkin                 PJM

This script will uninstall all versions of Oracle Java JRE older than $ChocoPkgCurrentVersion.
If Oracle Java JRE jre is not installed by choco, it will be removed regardless if it's current.
The most recent version of jre8 will be choco install --force jre8 -y

Syncro Script Variables:

None

#>

Import-Module $env:SyncroModule
#The commented line below is just a debugging cheat
#Remove-Variable * -ErrorAction SilentlyContinue

########################################
## Uninstall Oracle Java JRE          ##
## Older than $ChocoPkgCurrentVersion ##
########################################

## Variables (Static, think before changing)
$ChocoPkgID="jre8"

## Functions
function Get-ChocoPkgCurrentVersion ($ChocoPkgID){
  $AppInfo_Repo=$((choco list $ChocoPkgID -e -r) -split '\|')
  if ($AppInfo_Repo){
    $global:ChocoPkgCurrentVersion=$AppInfo_Repo[1]
  }else{
    Write-Output "Error:choco did not return $ChocoPkgID`$ChocoPkgCurrentVersion. Exit 1"
    exit 1
  }
}
function Get-ChocoInstalledVersion($ChocoPkgID) {
  $AppInfo_Local=$((choco list $ChocoPkgID -e -r -l) -split '\|')
  if ($AppInfo_Local){
    $global:ChocoInstalledVersion=$AppInfo_Local[1]
  }else{
    $global:ChocoInstalledVersion=0
  }
}
function Get-ProductInfo {
  $global:CurrentOracleJava=$(Get-WmiObject -Class Win32_Product -Filter "Vendor like 'Oracle%%' and Name like 'Java%%' and NOT Name like 'Java Auto Updater' and Version >= '$ChocoPkgCurrentVersion'")
  $global:OldOracleJava=$(Get-WmiObject -Class Win32_Product -Filter "Vendor like 'Oracle%%' and Name like 'Java%%' and NOT Name like 'Java Auto Updater' and Version < '$ChocoPkgCurrentVersion'")
  $global:OldOracleJavaAutoUpdater=$(Get-WmiObject -Class Win32_Product -Filter "Vendor like 'Oracle%%' and Name like 'Java Auto Updater'")
}
function Stop-JavaApps {
  Get-CimInstance -ClassName 'Win32_Process' | Where-Object {$_.ExecutablePath -like '*Program Files\Java*'} | 
  Select-Object @{n='Name';e={$_.Name.Split('.')[0]}} | Stop-Process -Force
  Get-process -Name *iexplore* | Stop-Process -Force -ErrorAction SilentlyContinue
}

## Main
Get-ChocoPkgCurrentVersion $ChocoPkgID
Get-ChocoInstalledVersion $ChocoPkgID

if ($ChocoInstalledVersion -eq 0){
  $ChocoPkgCurrentVersion=99999
}

# Upgrade installed $ChocoPkgID if version out of date
# Skip if $ChocoPkgID not installed, i.e. $ChocoPkgCurrentVersion=99999
if (($ChocoPkgCurrentVersion -gt $ChocoInstalledVersion) -and ($ChocoPkgCurrentVersion -ne 99999)){
  choco upgrade $ChocoPkgID --only-upgrade-installed --no-progress -y
}

Get-ProductInfo

if ($OldOracleJava){ 
  Write-Output "Forcing any Java programs to quit."
  Stop-JavaApps
  Write-Output "Uninstalling ALL Oracle Java JRE older than $ChocoPkgCurrentVersion"
  $OldOracleJava.Uninstall() | Out-Null
}
if ((!($CurrentOracleJava)) -and ($OldOracleJavaAutoUpdater)){
  Write-Output "Uninstalling Oracle Java Updater since no version of JRE $ChocoPkgCurrentVersion or greater is installed"
  $OldOracleJavaAutoUpdater.Uninstall() | Out-Null
} 
if ($ChocoPkgCurrentVersion -eq 99999){
  choco install $ChocoPkgID --force --no-progress -y
}  
