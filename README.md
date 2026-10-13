# Zabbix-Scripts

Überwachung für das Homelab mit **Zabbix 7.0** und Telegram-Meldungen.
Die Skripte installieren den **Zabbix Agent 2** auf deinen Rechnern. Die Rechner melden sich danach selbst im Zabbix-Server an (Autoregistrierung).

Es stehen keine Passwörter, Tokens oder IP-Adressen in den Skripten. Die Zabbix-IP gibst du beim Aufruf mit.

## Inhalt

| Datei | Wofür |
|---|---|
| `install.sh` | Agent installieren: Linux (Ubuntu/Debian/RHEL) und macOS |
| `install.ps1` | Agent installieren: Windows |
| `uninstall.sh` / `uninstall.ps1` | Agent wieder entfernen |
| `update.sh` | Offene Updates anzeigen und installieren (Ubuntu/Debian) |
| `Homelab-Linux-extras.yaml` | Zabbix-Template: Erreichbarkeit, Updates, Download/Upload, Speedtest |
| `Homelab-Ping.yaml` | Zabbix-Template für Router, Access Points, Switches (nur Ping) |
| `diun/compose.yaml` | Meldet per Telegram, wenn es neue Docker-Images gibt |

---

## Reihenfolge: So richtest du alles ein

1. [Zabbix vorbereiten](#1-zabbix-vorbereiten-einmalig) (Templates importieren, Autoregistrierung, Telegram-Stufen)
2. [Agent auf jedem Server installieren](#2-agent-auf-den-rechnern-installieren)
3. [Router, APs, Switches per Ping eintragen](#3-router-aps-und-switches-per-ping)
4. [Docker-Updates melden lassen (Diun)](#4-docker-updates-diun)
5. [Prüfen, ob alles läuft](#5-prüfen)

Wenn du schon Agents installiert hast und nur aktualisierst: Schritt 1 (Templates neu importieren) und dann auf jedem Server `git pull && sudo bash install.sh ZABBIX-IP`.

---

## 1. Zabbix vorbereiten (einmalig)

### 1.1 Templates importieren

**Data collection → Templates → Import** (rechts oben). Datei wählen, dann die Import-Regeln einstellen:

- **Templates, Template groups, Items, Triggers, Macros:** bei **Create new** und **Update existing** je einen Haken setzen.
- Alles andere kann so bleiben.

Dann **Import**. Das machst du für beide Dateien:

- `Homelab-Linux-extras.yaml`
- `Homelab-Ping.yaml`

Bei einem späteren Update derselben Dateien einfach genauso nochmal importieren. Die Einträge werden aktualisiert, es entstehen keine Doppelten.

Falls du früher schon eine alte Datei `Homelab-Speedtest.yaml` importiert hast: Template **Homelab Speedtest** vorher löschen (Data collection → Templates → Haken → Delete), sonst gibt es doppelte Werte.

### 1.2 Autoregistrierung

**Alerts → Actions → Autoregistration actions → Create action**, pro System eine Action:

| Bedingung (Host metadata contains) | Operationen |
|---|---|
| `Linux` | Add host · Add to host groups `Linux servers` · Link to templates `Linux by Zabbix agent` **und** `Homelab Linux extras` |
| `Windows` | Add host · Link to templates `Windows by Zabbix agent` |
| `macOS` | Add host · Link to templates `macOS by Zabbix agent` |

Neue Rechner erscheinen danach nach 1–2 Minuten unter **Data collection → Hosts**.

Für Docker-Hosts zusätzlich `Docker by Zabbix agent 2` verknüpfen. Das Skript fügt den Benutzer `zabbix` automatisch der Docker-Gruppe hinzu.

### 1.3 Template auf bestehende Hosts legen

Für Rechner, die es schon gibt: **Data collection → Hosts**, Hosts ankreuzen, **Mass update → Link templates → Add** → `Homelab Linux extras` → **Update**.

### 1.4 Telegram: nur wichtige Dinge aufs Handy

**Users → Users → Admin → Reiter Media → Telegram → Edit**, bei **Use if severity** nur **High** und **Disaster** angehakt lassen, den Rest abhaken.

Die Telegram-Einrichtung selbst (Media type, Bot, Chat-ID) hast du schon. Der Bot-Token gehört nur in das Token-Feld von Zabbix, nie in Chats oder ins Repo. Wurde er irgendwo gezeigt: bei `@BotFather` mit `/revoke` einen neuen erzeugen.

### 1.5 Was gemeldet wird

| Meldung | Stufe | Telegram? |
|---|---|---|
| Server nicht erreichbar (Agent antwortet 30 Sek. nicht, Abfrage alle 10 Sek.) | **Disaster** | ja |
| Router / AP / Switch nicht per Ping erreichbar (3 Pings à 10 Sek.) | **Disaster** | ja |
| Sicherheits-Updates verfügbar | **High** | ja |
| Normale Updates verfügbar | **Average** | nein, nur im Log (Monitoring → Problems) |
| Neustart nötig | Warning | nein |
| Internet-Download unter Mindestwert | Warning | nein |

Eine Ausfall-Meldung kommt etwa 30–40 Sekunden nach dem Ausfall. Schneller geht es nicht, weil Zabbix kürzere Zeitfenster bei diesen Triggern nicht zulässt und kurze Aussetzer sonst Fehlalarme erzeugen würden.

CPU, RAM, Festplatte und Uptime jedes Rechners liefert das Template `Linux by Zabbix agent`.

### 1.6 Download und Upload

- **`Download live` / `Upload live`:** misst **jede Minute** die tatsächliche Datenrate der Netzwerkkarte jedes Servers (bit/s). Kostet nichts.
- **Speedtest (Maximum):** misst die maximale Geschwindigkeit der Internetleitung, nur alle **6 Stunden** pro Server (zeitversetzt). Ein Speedtest jede Minute würde die Leitung dauernd auslasten.
- Mindest-Download einstellen: Makro `{$SPEEDTEST.DOWN.MIN}` am Host (Wert in bit/s, Standard 10000000 = 10 Mbit/s).
- Speedtest nicht installieren: `NO_SPEEDTEST=1 sudo ./install.sh ZABBIX-IP`

---

## 2. Agent auf den Rechnern installieren

### Linux / macOS

```bash
sudo apt install -y git          # nur falls git fehlt
git clone https://github.com/KiwiLetsPlay/Zabbix-Scripts.git
cd Zabbix-Scripts
sudo bash install.sh ZABBIX-IP [HOSTNAME]
```

`ZABBIX-IP` ist die echte IP deiner Zabbix-VM (bei dir `192.168.2.105`). Nicht die Platzhalter aus der Anleitung eintippen.
`HOSTNAME` ist optional und der Name, der in Zabbix erscheint. Ohne Angabe wird der Name des Rechners genommen.

Beispiel: `sudo bash install.sh 192.168.2.105 paperless-vm`

Prüfen: `systemctl status zabbix-agent2` muss `active (running)` zeigen.

**Aktualisieren** (neue Version der Skripte): im Ordner `Zabbix-Scripts`

```bash
git pull
sudo bash install.sh ZABBIX-IP
```

Minimale LXC-Container brauchen zuerst: `apt install -y curl sudo git`.

### Windows

PowerShell **als Administrator** öffnen (Startmenü → "PowerShell" → Rechtsklick → Als Administrator ausführen).

```powershell
git clone https://github.com/KiwiLetsPlay/Zabbix-Scripts.git
cd Zabbix-Scripts
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1 -Server ZABBIX-IP
```

Ohne Git: auf GitHub **Code → Download ZIP**, entpacken, in den Ordner wechseln und die letzten beiden Befehle ausführen.
Optional: `-HostName NAME`, `-Version 7.0.31`, `-Msi C:\pfad\agent.msi` (lokale MSI).
Prüfen: `services.msc` → "Zabbix Agent 2" läuft.

### Privates Repo

Bei `git clone` wird nach Zugangsdaten gefragt:

- **Username:** `KiwiLetsPlay`
- **Password:** ein GitHub **Personal Access Token** (kein normales Passwort)

Token erstellen: GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → nur dieses Repo, **Contents: Read-only**. Beim Eintippen wird nichts angezeigt, das ist normal. Ist das Repo öffentlich, entfällt das.

### Nicht per Skript

- **Zabbix-VM selbst:** Der Container `zabbix-agent` aus der Compose-Datei übernimmt das (Port-Konflikt auf 10050).
- **Home Assistant OS:** Add-on "Zabbix Agent 2" aus dem Community-Repo verwenden.
- **IPFire, Router, Switches, APs:** keine Agent-Installation, siehe Schritt 3.
- **Proxmox:** Template `Proxmox VE by HTTP` mit API-Token (Rolle PVEAuditor).

### Netzwerk / Firewall

- Port **10051** muss vom Rechner zur Zabbix-VM erreichbar sein (aktive Checks).
- Port **10050** muss von der Zabbix-VM zum Rechner erreichbar sein (passive Checks).
- Für VLAN 10 in IPFire beide Ports zur Zabbix-VM freigeben.

---

## 3. Router, APs und Switches per Ping

Für jedes Gerät: **Data collection → Hosts → Create host**

- **Host name:** z. B. `Router`, `AP-Wohnzimmer`
- **Templates:** `Homelab Ping` (nicht das Standard-Template "ICMP Ping")
- **Host groups:** `Network devices` (neu anlegen, falls nicht vorhanden)
- **Interfaces:** **Add → Agent**, bei IP die Adresse des Geräts. Der Agent muss dort nicht laufen, die Adresse wird nur zum Anpingen benutzt.

Das Gerät bleibt in der Hostliste grau (kein ZBX-Symbol). Das ist richtig. Ob es erreichbar ist, siehst du unter **Monitoring → Latest data** (`icmpping` = 1) und bei einem Ausfall als Disaster-Meldung.

---

## 4. Docker-Updates (Diun)

Zabbix meldet keine neuen Container-Images. Dafür gibt es Diun: Es prüft täglich um 7 Uhr, ob es für laufende Container neue Images gibt, und schreibt per Telegram. Es aktualisiert nichts selbst.

Auf **jedem Server mit Docker** einmal einrichten (Nextcloud, Paperless, Proxy, ...):

```bash
cd ~/Zabbix-Scripts && git pull
cp -r diun ~/diun
cd ~/diun
nano .env
```

In die Datei `.env` schreiben (mit den echten Werten):

```
TELEGRAM_TOKEN=dein-bot-token
TELEGRAM_CHAT_ID=deine-chat-id
```

Speichern (Strg+O, Enter, Strg+X), dann:

```bash
docker compose up -d
docker compose logs diun            # Fehler ansehen
docker compose exec diun diun image list   # welche Images werden beobachtet
```

Test ohne bis 7 Uhr zu warten: in `compose.yaml` den Zeitplan `0 7 * * *` auf `*/5 * * * *` ändern, `docker compose up -d` neu ausführen, danach wieder zurückstellen.

Die Datei `.env` niemals ins Repo hochladen.

Entfernen: im Ordner `~/diun` `docker compose down`.

---

## 5. Prüfen

### Linux

```bash
systemctl status zabbix-agent2                      # active (running) = gut
sudo systemctl restart zabbix-agent2                # Neustart
sudo systemctl enable zabbix-agent2                 # Start beim Booten
sudo tail -n 30 /var/log/zabbix/zabbix_agent2.log   # Log
sudo journalctl -u zabbix-agent2 -n 30 --no-pager   # Systemlog des Dienstes
sudo ss -tlnp | grep 10050                          # lauscht der Agent?
grep -E '^(Server|ServerActive|Hostname|HostMetadata)=' /etc/zabbix/zabbix_agent2.conf
nc -zv ZABBIX-IP 10051                              # Zabbix-Server erreichbar?
```

Fehlt `nc`: `sudo apt install -y netcat-openbsd`.

Einzelne Messwerte direkt testen:

```bash
sudo zabbix_agent2 -t homelab.alive      # muss 1 zeigen
sudo zabbix_agent2 -t homelab.net.rx     # Zahl (empfangene Bytes)
sudo zabbix_agent2 -t updates.count      # Anzahl offener Updates
sudo zabbix_agent2 -t updates.security   # davon Sicherheits-Updates
```

### macOS

```bash
sudo launchctl list | grep zabbix
sudo tail -n 30 /var/log/zabbix/zabbix_agent2.log
```

### Windows (PowerShell)

```powershell
Get-Service "Zabbix Agent 2"
Restart-Service "Zabbix Agent 2"
Test-NetConnection ZABBIX-IP -Port 10051          # TcpTestSucceeded : True = gut
Get-Content "C:\Program Files\Zabbix Agent 2\zabbix_agent2.log" -Tail 30
```

### In Zabbix

- **Data collection → Hosts:** grüne `ZBX`-Kachel bei "Availability" = Agent erreichbar.
- **Monitoring → Latest data:** Host auswählen, Filter anwenden. Es sollten CPU-, RAM-, Disk- und `Download live`-Werte erscheinen. `Download live` zeigt erst nach etwa 2 Minuten einen Wert.
- **Monitoring → Problems:** aktive Meldungen.

### Alarm testen

Auf einem Test-Server `sudo systemctl stop zabbix-agent2`. Nach etwa 30–40 Sekunden muss die Disaster-Meldung in Telegram ankommen. Danach `sudo systemctl start zabbix-agent2`, die Meldung verschwindet wieder.

---

## Updates auf den Servern installieren

```bash
cd ~/Zabbix-Scripts
./update.sh --list     # nur anzeigen, was ansteht
./update.sh            # anzeigen und nach Rückfrage installieren
./update.sh --yes      # ohne Rückfrage installieren
```

Danach dauert es bis zu 1 Stunde, bis die Meldung in Zabbix verschwindet (Prüfintervall). Sofort: **Monitoring → Latest data → Item `updates.count` → Execute now**. Zeigt `update.sh` "Neustart nötig", erst neu starten (`sudo reboot`).

---

## Deinstallieren

Linux / macOS:

```bash
cd ~/Zabbix-Scripts
sudo bash uninstall.sh
```

Windows (PowerShell als Administrator):

```powershell
cd Zabbix-Scripts
Set-ExecutionPolicy -Scope Process Bypass
.\uninstall.ps1
```

Das entfernt Agent, Konfiguration, Speedtest-Cronjob und die Hilfsskripte. `speedtest-cli`, `jq` und `cron` bleiben installiert.

Danach noch von Hand:

1. In Zabbix den Host löschen: **Data collection → Hosts**, Haken, **Delete**. Sonst bleibt er als "nicht erreichbar" stehen und schickt Disaster-Meldungen.
2. Diun auf dem Rechner entfernen, falls eingerichtet: `cd ~/diun && docker compose down`.

---

## Fehlersuche

| Problem | Lösung |
|---|---|
| `Permission denied` beim Start von `./install.sh` | `sudo bash install.sh ZABBIX-IP` benutzen, oder einmal `chmod +x install.sh`. |
| `git pull` bricht ab ("local changes ... would be overwritten") | `git checkout -- .`, dann `git pull`. Dauerhaft: `git config core.fileMode false` |
| Du startest ein altes Skript | Alte Kopien (z. B. in `~/nextcloud`) löschen und immer aus dem frisch geklonten Ordner `Zabbix-Scripts` arbeiten. |
| `E: Unable to locate package zabbix-agent2` | Zabbix-Paketquelle fehlt. Das Skript richtet sie ein. Nochmal ausführen, die Fehlermeldung im Terminal lesen. Braucht Internet auf dem Rechner. |
| Download-Fehler (404) | Version prüfen (`ZBX_VERSION` in `install.sh`, `-Version` in `install.ps1`) auf <https://www.zabbix.com/download_agents>. |
| Agent startet nicht, in der Konfig steht `ZABBIX-IP` oder `IP-DER-ZABBIX-VM` | Du hast den Platzhalter mitgetippt. Nochmal mit der echten IP ausführen, z. B. `sudo bash install.sh 192.168.2.105`. |
| Host erscheint nicht in Zabbix | Bedingung der Autoregistrierungs-Action muss genau `Linux` / `Windows` / `macOS` heißen. Port 10051 prüfen (`nc -zv ZABBIX-IP 10051`), Agent-Log ansehen. |
| Host ist rot (ZBX) | Port 10050 von der Zabbix-VM zum Rechner blockiert (Firewall/IPFire), oder Agent läuft nicht. |
| Latest data ist leer | Oben im Filter den Host auswählen und **Apply** drücken. Wenn Items fehlen: Template `Homelab Linux extras` importiert **und** am Host verknüpft? |
| `Download live` hat keinen Wert | Erst nach etwa 2 Minuten. Sonst `sudo zabbix_agent2 -t homelab.net.rx` ausführen, es muss eine Zahl kommen. Kommt "unsupported item key", Agent mit `sudo systemctl restart zabbix-agent2` neu starten. |
| Telegram-Test: "unresolved macros" | Beim Test in Zabbix die Felder (To, Subject, Message) mit echten Werten füllen, nicht mit `{ALERT.SENDTO}`. |
| Telegram schickt auch normale Updates | Beim Benutzer Admin → Media → Telegram nur **High** und **Disaster** angehakt lassen. |
| Telegram schickt gar nichts | Chat-ID richtig? Dem Bot einmal `/start` schicken. Alerts → Actions: Action "Report problems to Zabbix administrators" aktiv? Bot-Token im Media type gesetzt? |
| Update-Meldung bleibt nach `apt upgrade` | Prüfintervall 1 Stunde, Item mit **Execute now** neu abfragen. Bleibt sie: `apt list --upgradable` ansehen (zurückgehaltene Pakete: `sudo apt full-upgrade`), oder `/var/run/reboot-required` existiert (Neustart nötig). |
| Diun schickt nichts | `docker compose logs diun` ansehen. Meist falscher Token/Chat-ID in `.env`. |
