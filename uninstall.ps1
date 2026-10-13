# Entfernt den Zabbix Agent 2 unter Windows. Als Administrator ausfuehren.
$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Bitte als Administrator starten."; exit 1 }

Get-Service "Zabbix Agent 2" -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue

$keys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
$app = Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Zabbix Agent 2*" } | Select-Object -First 1
if (-not $app) { Write-Host "Zabbix Agent 2 ist nicht installiert."; exit 0 }

$p = Start-Process msiexec.exe -ArgumentList @("/x", $app.PSChildName, "/qn", "/l*v", "`"$env:TEMP\zabbix_uninstall.log`"") -Wait -PassThru
if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { Write-Error "Deinstallation fehlgeschlagen (Code $($p.ExitCode)), Log: $env:TEMP\zabbix_uninstall.log"; exit 1 }
Write-Host "Zabbix Agent 2 entfernt. Den Host in Zabbix loeschst du von Hand: Data collection -> Hosts."
