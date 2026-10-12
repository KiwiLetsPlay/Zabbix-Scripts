# Zabbix-Scripts
ZABBIX AGENT INSTALLIEREN - ANLEITUNG
=====================================

Dateien: install.sh (Linux/Mac), install.ps1 (Windows)
Ersetze IP-DER-ZABBIX-VM durch die echte IP, z. B. 192.168.2.230

--------------------------------------------------
1) LINUX-VM (Nextcloud, Paperless, OMV, ...)
--------------------------------------------------
a) install.sh auf die VM kopieren (WinSCP/FileZilla per Drag & Drop
   oder: scp install.sh USER@IP-DER-VM:~/ )
b) Auf der VM:
     chmod +x install.sh
     sudo ./install.sh IP-DER-ZABBIX-VM
   Mit eigenem Namen in Zabbix:
     sudo ./install.sh IP-DER-ZABBIX-VM nextcloud-vm
c) Pruefen:
     systemctl status zabbix-agent2      (muss "active (running)" zeigen)

--------------------------------------------------
2) MAC
--------------------------------------------------
Terminal:
     chmod +x install.sh
     sudo ./install.sh IP-DER-ZABBIX-VM

--------------------------------------------------
3) WINDOWS
--------------------------------------------------
a) Startmenue -> "PowerShell" -> Rechtsklick -> Als Administrator ausfuehren
b) In den Ordner wechseln:   cd $HOME\Downloads
c) Einmalig fuer dieses Fenster:
     Set-ExecutionPolicy -Scope Process Bypass
d) Ausfuehren:
     .\install.ps1 -Server IP-DER-ZABBIX-VM
e) Pruefen: services.msc -> "Zabbix Agent 2" laeuft

--------------------------------------------------
4) IN ZABBIX (einmalig)
--------------------------------------------------
Alerts -> Actions -> Autoregistration actions -> Create action
Drei Actions anlegen, je eine pro System:
  Bedingung: Host metadata contains Linux   (bzw. Windows / macOS)
  Operationen: Add host + Link template
     Linux   -> "Linux by Zabbix agent"
     Windows -> "Windows by Zabbix agent"
     macOS   -> "macOS by Zabbix agent"

Danach erscheint der Rechner nach 1-2 Minuten unter
Data collection -> Hosts.

--------------------------------------------------
5) NETZ / FIREWALL
--------------------------------------------------
- Port 10051 muss vom Rechner zur Zabbix-VM erreichbar sein.
- VLAN 10: in IPFire Port 10050/10051 zur Zabbix-VM erlauben.

--------------------------------------------------
6) FEHLER
--------------------------------------------------
- Download-Fehler: Version pruefen (ZBX_VERSION bzw. -Version) auf
  https://www.zabbix.com/download_agents
- Host erscheint nicht: Agent-Log pruefen
  Linux:   sudo tail -n 30 /var/log/zabbix/zabbix_agent2.log
  Windows: Log im Zabbix-Agent-Ordner
- Tipp: Erst eine Test-VM (z. B. Nextcloud), dann den Rest.
