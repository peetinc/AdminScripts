<#
# Script Name:              Uninstall-OracleJavaJRE.ps1
# Script Author:            Peet McKinney @ Artichoke Consulting

# Changelog                 
2021.05.06              Initial Checkin                 PJM

This script will uninstall all versions of Oracle Java JRE older than $KeepVersion

Syncro Script Variables:

None

#>

Import-Module $env:SyncroModule

###############################
## Uninstall Oracle Java JRE ##
## Older than $KeepVersion   ##
###############################

## Variables (Must Set)
$KeepVersion="8.0.2910.11" #Current JRE 8 as of 2021.05.06 

## Variables (Runtime)
$CurrentOracleJava=$(Get-WmiObject -Class Win32_Product -Filter "Vendor like 'Oracle%%' and Name like 'Java%%' and NOT Name like 'Java Auto Updater' and Version >= '$KeepVersion'")
$OldOracleJava=$(Get-WmiObject -Class Win32_Product -Filter "Vendor like 'Oracle%%' and Name like 'Java%%' and NOT Name like 'Java Auto Updater' and Version < '$KeepVersion'")
$OldOracleJavaAutoUpdater=$(Get-WmiObject -Class Win32_Product -Filter "Vendor like 'Oracle%%' and Name like 'Java Auto Updater'")

## Main
if ($OldOracleJava){
  Write-Output "Uninstalling Oracle Java JRE older than $KeepVersion"
  Write-Output "Forcing any Java programs to quit."
  Get-CimInstance -ClassName 'Win32_Process' | Where-Object {$_.ExecutablePath -like '*Program Files\Java*'} | 
  Select-Object @{n='Name';e={$_.Name.Split('.')[0]}} | Stop-Process -Force
  Get-process -Name *iexplore* | Stop-Process -Force -ErrorAction SilentlyContinue
  $OldOracleJava.Uninstall() | Out-Null
}
if ((!($CurrentOracleJava)) -and ($OldOracleJavaAutoUpdater)){
  Write-Output "Uninstalling Oracle Java Updater since no version of JRE $KeepVersion or greater is installed"
  $OldOracleJavaAutoUpdater.Uninstall() | Out-Null
}
if ($CurrentOracleJava){
  Write-Output "Currently installed versions of Oracle Java JRE:"
  ForEach ($version in $CurrentOracleJava.Name) {
  Write-Output $CurrentOracleJava.Name
  }
} 
