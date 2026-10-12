# Zabbix-Scripts

Installer für den **Zabbix Agent 2** mit automatischer Registrierung im Zabbix-Server.

| Datei | System |
|---|---|
| `install.sh` | Linux (Ubuntu/Debian/RHEL-artig) und macOS, erkennt das System selbst |
| `install.ps1` | Windows |

Die Zabbix-IP steht nicht im Skript, sie wird beim Aufruf mitgegeben. Es sind keine Passwörter oder Tokens enthalten.

## Linux / macOS

Skripte per Git holen und ausführen:

```bash
sudo apt install -y git          # nur falls git fehlt
git clone https://github.com/KiwiLetsPlay/Zabbix-Scripts.git
cd Zabbix-Scripts
chmod +x install.sh
sudo ./install.sh IP-DER-ZABBIX-VM [HOSTNAME]
```

Beispiel: `sudo ./install.sh 192.168.2.230 paperless-vm`

Später aktualisieren: im Ordner `Zabbix-Scripts` einfach `git pull`.

Prüfen: `systemctl status zabbix-agent2` (muss `active (running)` zeigen)

In minimalen LXC-Containern zusätzlich: `apt install -y curl sudo git`.

### Privates Repo

Bei `git clone` wird nach Zugangsdaten gefragt:
- **Username:** `KiwiLetsPlay`
- **Password:** ein GitHub **Personal Access Token** (kein normales Passwort)

Token erstellen: GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → nur dieses Repo, **Contents: Read-only**. Den Token nirgends ablegen oder weitergeben.
Beim Eintippen wird nichts angezeigt, das ist normal. Ist das Repo öffentlich, entfällt das.

## Windows

PowerShell **als Administrator**:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1 -Server IP-DER-ZABBIX-VM
```

Optional: `-HostName NAME`, `-Version 7.0.31`, `-Msi C:\pfad\agent.msi` (lokale MSI, falls kein Download möglich).

Prüfen: `services.msc` → "Zabbix Agent 2" läuft.

## Einrichtung in Zabbix (einmalig)

**Alerts → Actions → Autoregistration actions → Create action**, pro System eine Action:

| Bedingung (Host metadata contains) | Operationen |
|---|---|
| `Linux` | Add host, Add to host groups `Linux servers`, Link to templates `Linux by Zabbix agent` |
| `Windows` | Add host, Link to templates `Windows by Zabbix agent` |
| `macOS` | Add host, Link to templates `macOS by Zabbix agent` |

Danach erscheint der Rechner nach 1–2 Minuten unter **Data collection → Hosts**.

Für Docker-Hosts zusätzlich das Template `Docker by Zabbix agent 2` verknüpfen. Das Skript fügt den Benutzer `zabbix` automatisch der Docker-Gruppe hinzu.

## Netzwerk

- Port **10051** muss vom Rechner zur Zabbix-VM erreichbar sein (aktive Checks).
- Port **10050** muss von der Zabbix-VM zum Rechner erreichbar sein (passive Checks).
- Für VLAN 10 in IPFire beide Ports zur Zabbix-VM freigeben.

## Nicht per Skript

- **Zabbix-VM selbst:** Der Container `zabbix-agent` aus der Compose-Datei übernimmt das (Port-Konflikt auf 10050).
- **Home Assistant OS, IPFire:** keine normale Konsole, Überwachung per Ping/HTTP/SNMP.

## Fehlersuche

- **Download-Fehler:** Version prüfen (`ZBX_VERSION` in `install.sh`, `-Version` in `install.ps1`) auf <https://www.zabbix.com/download_agents>.
- **Host erscheint nicht:** Bedingung der Action muss genau `Linux` / `Windows` / `macOS` heißen. Agent-Log prüfen: `sudo tail -n 30 /var/log/zabbix/zabbix_agent2.log`.
