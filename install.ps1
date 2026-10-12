# Zabbix Agent 2 Installer fuer Windows
# Aufruf (als Administrator):  .\install.ps1 -Server 192.168.2.X [-Msi C:\pfad\agent.msi]
param(
  [Parameter(Mandatory=$true)][string]$Server,
  [string]$HostName = $env:COMPUTERNAME,
  [string]$Version = "7.0.31",
  [string]$Msi = ""
)
$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Bitte als Administrator starten."; exit 1 }

if (-not $Msi) {
  $Major = ($Version -split '\.')[0..1] -join '.'
  $Url = "https://cdn.zabbix.com/zabbix/binaries/stable/$Major/$Version/zabbix_agent2-$Version-windows-amd64-openssl.msi"
  $Msi = Join-Path $env:TEMP "zabbix_agent2.msi"
  Write-Host "Lade $Url"
  Invoke-WebRequest -Uri $Url -OutFile $Msi -UseBasicParsing
}
$args = @("/i","`"$Msi`"","/qn","/l*v","`"$env:TEMP\zabbix_install.log`"",
  "SERVER=$Server","SERVERACTIVE=$Server","HOSTNAME=$HostName","HOSTMETADATA=Windows")
$p = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru
if ($p.ExitCode -ne 0) { Write-Error "Installation fehlgeschlagen (Code $($p.ExitCode)), Log: $env:TEMP\zabbix_install.log"; exit 1 }
Write-Host "Fertig. Agent meldet sich bei $Server als '$HostName' (Metadata: Windows)."
