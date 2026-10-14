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
| `update.sh` | Offene Updates auf dem Server selbst anzeigen und installieren (Ubuntu/Debian) |
| `Homelab-Linux-extras.yaml` | Zabbix-Template: Erreichbarkeit, Updates (mit Liste), Download/Upload, Speedtest |
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

Bei einem späteren Update derselben Dateien einfach genauso nochmal importieren. Die Einträge werden aktualisiert, es entstehen keine Doppelten. Setze zusätzlich bei Items und Triggers den Haken **Delete missing**, damit alte, nicht mehr gebrauchte Einträge verschwinden.

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

- **Zabbix-VM selbst:** Dort läuft schon ein Agent-Container auf Port 10050. Damit beide nicht kollidieren und der Zabbix-Container den Agent erreicht, bekommt der Agent aus `install.sh` einen anderen Port und erlaubt zusätzlich das Docker-Netz:
  ```bash
  cd ~/Zabbix-Scripts
  SERVER_EXTRA="172.16.0.0/12" AGENT_PORT=10055 sudo -E bash install.sh 192.168.2.105 "Zabbix server"
  ```
  Danach in Zabbix beim Host `Zabbix server` unter **Interfaces → Agent** die IP `192.168.2.105`, Port `10055`, **Connect to: IP** eintragen und DNS leeren.
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
sudo zabbix_agent2 -t 'vfs.file.exists[/proc/uptime]'   # muss 1 zeigen
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

### Simulationen: Updates vortäuschen

So prüfst du die ganze Kette (Messwert, Trigger, Problem, Telegram), ohne dass wirklich Updates anstehen. Alles auf dem Server, der getestet wird (hier Pihole). Die Zeilen einzeln eingeben.

**Vorbereitung (Sicherung der Einstellung):**
```
sudo cp /etc/zabbix/zabbix_agent2.d/homelab-updates.conf /root/homelab-updates.conf.bak
```

**Test A: normale Updates (nur Current problems, kein Telegram)**
```
sudo sed -i 's|^UserParameter=updates.count,.*|UserParameter=updates.count,echo 3|' /etc/zabbix/zabbix_agent2.d/homelab-updates.conf
```
```
sudo systemctl restart zabbix-agent2
```
In Zabbix: **Monitoring → Latest data → Host wählen**, bei „Pending updates“ Haken setzen, **Execute now** klicken, 30 Sekunden warten, **noch einmal Execute now** (der Trigger braucht zwei Messungen hintereinander). Unter **Monitoring → Problems** steht jetzt „3 Updates verfügbar“ (Average). Auf dem Handy darf nichts ankommen.

**Test B: Sicherheitsupdates (Current problems und Telegram)**
```
sudo sed -i 's|^UserParameter=updates.security,.*|UserParameter=updates.security,echo 1|' /etc/zabbix/zabbix_agent2.d/homelab-updates.conf
```
```
sudo systemctl restart zabbix-agent2
```
Wieder bei „Pending security updates“ zweimal **Execute now**. Das Problem erscheint als High und die Telegram-Nachricht kommt an.

**Zurücksetzen (wichtig, sonst meldet der Server dauerhaft falsche Zahlen):**
```
sudo cp /root/homelab-updates.conf.bak /etc/zabbix/zabbix_agent2.d/homelab-updates.conf
```
```
sudo systemctl restart zabbix-agent2
```
Danach bei beiden Messwerten zweimal **Execute now**. Die Test-Probleme schließen sich von selbst.

### Welche Updates sind es?

Der Name des Problems zeigt die Pakete direkt an, zum Beispiel: `pihole: 2 Updates verfuegbar: libssl3*, curl`. Ein `*` hinter dem Namen bedeutet Sicherheits-Update. Es werden bis zu 8 Pakete genannt, danach steht „(+N weitere)“. Dieselbe Liste steht in Latest data beim Messwert „Pending updates list“. Der Text kommt auch in der Telegram-Nachricht bei Sicherheitsupdates. Dafür muss die neue `Homelab-Linux-extras.yaml` importiert (Update existing) und `install.sh` auf den Servern neu ausgeführt sein.

---

## FRITZ!Box und DSL-Leitung (UPnP)

Ungetestet an einer echten FRITZ!Box. Die Abfrage läuft über UPnP, also ohne Agent.

1. **In der FRITZ!Box:** Heimnetz → Netzwerk → Netzwerkeinstellungen → Heimnetzfreigaben. Dort **Zugriff für Anwendungen zulassen** und **Statusinformationen über UPnP übertragen** aktivieren.
2. **In Zabbix:** `Homelab-FRITZBox.yaml` importieren (Data collection → Templates → Import, Create new und Update existing).
3. **Host anlegen:** Data collection → Hosts → Create host. Name `FRITZ!Box`, Gruppe `Network devices`, Interface **Agent** mit der IP der FRITZ!Box (Port egal), Templates `Homelab Ping` und `Homelab FRITZ!Box`.
4. **Prüfen:** Nach etwa einer Minute stehen unter Latest data `DSL Sync Download (Maximum)`, `Leitungsstatus`, `Internetverbindung Status`, `Online seit` und die Live-Datenraten.

Meldungen: Leitung nicht synchron und Internetverbindung getrennt (High, mit Telegram), Verbindung neu aufgebaut und Sync unter Mindestwert (Makro `{$FRITZ.SYNC.DOWN.MIN}` am Host anpassen).

Internet-Erreichbarkeit: zwei Ping-Hosts `Internet Cloudflare` (1.1.1.1) und `Internet Google` (8.8.8.8) mit dem Template `Homelab Ping`.

---

## Updates per Knopf in Zabbix installieren

Du siehst pro Server, **welche** Updates anstehen (`Pending updates list`, ein `*` hinter dem Namen = Sicherheits-Update), und kannst sie mit einem Klick starten. Das läuft ohne Fernbefehle (`system.run` bleibt aus): Der Agent bekommt nur einen festen Befehl, und nur der Zabbix-Server darf ihn auslösen.

### 1. Auf den Servern freischalten (nicht auf Proxmox `home`)

```bash
cd ~/Zabbix-Scripts && git pull
sudo bash install.sh 192.168.2.105 --update-button
```

Dort, wo du einen eigenen Namen vergeben hattest, denselben Namen wieder angeben (`sudo bash install.sh 192.168.2.105 NAME --update-button`). Ohne `--update-button` bleibt der Knopf aus, und ein früher gesetzter Knopf wird wieder entfernt.

Auf der Zabbix-VM (als root):

```bash
SERVER_EXTRA="172.16.0.0/12" AGENT_PORT=10055 bash install.sh 192.168.2.105 "Zabbix server" --update-button
```

### 2. Skripte in Zabbix anlegen (einmalig)

Voraussetzung: `Homelab-Linux-extras.yaml` ist neu importiert. Prüfen, ob `zabbix_get` im Server-Container vorhanden ist:

```bash
docker exec zabbix-docker-zabbix-server-1 which zabbix_get
```

Dann **Alerts → Scripts → Create script**:

| Feld | Wert |
|---|---|
| Name | `Updates installieren` |
| Scope | Manual host action |
| Type | Script |
| Execute on | Zabbix server |
| Commands | `zabbix_get -s {HOST.IP} -p {HOST.PORT} -k homelab.update.run` |
| Host group | nur die Gruppe, in der die freigeschalteten Server liegen (nicht `home`) |
| Enable user confirmation | an, Text: `Updates auf {HOST.NAME} jetzt installieren?` |

Zwei weitere Skripte nach demselben Muster (ohne Bestätigung, für alle Linux-Server):

| Name | Commands |
|---|---|
| `Offene Updates anzeigen` | `zabbix_get -s {HOST.IP} -p {HOST.PORT} -k updates.list` |
| `Update-Status anzeigen` | `zabbix_get -s {HOST.IP} -p {HOST.PORT} -k homelab.update.status` |

### 3. Benutzen

Auf einen Hostnamen klicken (Dashboard, Problems oder Hostliste) → Menü **Scripts** → `Updates installieren`. Zabbix meldet "Update gestartet". Den Fortschritt siehst du unter **Monitoring → Latest data** beim Eintrag `Update status` (LAEUFT ... / Ende ... / NEUSTART NOETIG). Danach den Eintrag `Pending updates` mit **Execute now** neu abfragen, sonst verschwindet die Meldung erst nach bis zu einer Stunde. Ein nötiger Neustart passiert **nicht** automatisch.

Im Dashboard zeigst du die Liste im Widget **Top hosts**: **Columns → Add**, Item `Pending updates list`, Display **As is**.

Entfernen: Server ohne `--update-button` neu installieren, oder `sudo bash uninstall.sh`.

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
| Rotes `i` bei „Pending updates“, Meldung „Timeout occurred while gathering data“ | `apt-get -s upgrade` braucht länger als die 3 Sekunden Standard-Timeout. Die `Homelab-Linux-extras.yaml` setzt für die Update-Messwerte deshalb 30 Sekunden. Neue YAML importieren (Update existing), dann bei den Messwerten **Execute now**. |
| Updates fehlen in Zabbix, obwohl `apt update` welche zeigt | Zabbix zählt mit den Paketlisten des Servers. Sind die veraltet, steht dort `0`. `install.sh` richtet deshalb alle 6 Stunden ein `apt-get update` ein (`/etc/cron.d/homelab-apt-update`). Einmal neu installieren oder von Hand `sudo apt update` ausführen, dann beim Messwert **Execute now**. |
| Update-Meldung bleibt nach `apt upgrade` | Prüfintervall 1 Stunde, Item mit **Execute now** neu abfragen. Bleibt sie: `apt list --upgradable` ansehen (zurückgehaltene Pakete: `sudo apt full-upgrade`), oder `/var/run/reboot-required` existiert (Neustart nötig). |
| Knopf `Updates installieren` meldet Fehler | Mit `--update-button` installiert? Prüfen: `ls /etc/sudoers.d/zabbix-homelab-update` und `sudo -l -U zabbix` (dort muss `homelab-update.sh start` stehen). Fehlt `zabbix_get` im Container, schick die Fehlermeldung. |
| Diun schickt nichts | `docker compose logs diun` ansehen. Meist falscher Token/Chat-ID in `.env`. |
