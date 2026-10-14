#!/usr/bin/env bash
# Zabbix Agent 2 Installer fuer Linux und macOS (erkennt das System automatisch)
# Aufruf: sudo ./install.sh <ZABBIX-SERVER-IP> [HOSTNAME] [--update-button]
set -euo pipefail

# Aufruf-Optionen: --update-button schaltet den "Updates installieren"-Knopf in Zabbix frei
UPDATE_BUTTON="${UPDATE_BUTTON:-0}"
ARGS=()
for a in "$@"; do
  case "$a" in
    --update-button) UPDATE_BUTTON=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
SERVER="${ARGS[0]:-}"
HOSTNAME_ARG="${ARGS[1]:-$(hostname)}"
ZBX_MAJOR="7.0"
ZBX_VERSION="${ZBX_VERSION:-7.0.31}"   # nur fuer macOS-Paket noetig

[ -z "$SERVER" ] && { echo "Aufruf: sudo $0 <ZABBIX-SERVER-IP> [HOSTNAME] [--update-button]"; exit 1; }
[ "$(id -u)" -ne 0 ] && { echo "Bitte mit sudo starten."; exit 1; }

OS="$(uname -s)"
# Optional (z.B. fuer die Zabbix-VM): SERVER_EXTRA="172.16.0.0/12" AGENT_PORT=10055
CONF_APPEND="
Server=${SERVER}${SERVER_EXTRA:+,${SERVER_EXTRA}}
ServerActive=${SERVER}
Hostname=${HOSTNAME_ARG}
${AGENT_PORT:+ListenPort=${AGENT_PORT}}
"

write_conf() { # $1 = conf-Datei, $2 = Metadata
  cp -n "$1" "$1.bak" 2>/dev/null || true
  sed -i.tmp -E '/^(Server|ServerActive|Hostname|HostMetadata|ListenPort)=/d' "$1" && rm -f "$1.tmp"
  printf '%sHostMetadata=%s\n' "$CONF_APPEND" "$2" >> "$1"
}

case "$OS" in
Linux)
  . /etc/os-release
  META="Linux"
  if command -v apt-get >/dev/null; then
    DIST="$ID"; VER="$VERSION_ID"
    DEB="/tmp/zabbix-release.deb"
    URL="https://repo.zabbix.com/zabbix/${ZBX_MAJOR}/${DIST}/pool/main/z/zabbix-release/zabbix-release_latest_${ZBX_MAJOR}+${DIST}${VER}_all.deb"
    if curl -fsSL "$URL" -o "$DEB"; then
      dpkg -i "$DEB"; apt-get update -y
    else
      echo "Zabbix-Repo-Paket nicht gefunden: $URL"
      echo "Versuche Distribution-Paket ..."
      apt-get update -y
    fi
    apt-get install -y zabbix-agent2 || { echo "FEHLER: zabbix-agent2 nicht installierbar (Repo-URL pruefen)."; exit 1; }
  elif command -v dnf >/dev/null || command -v yum >/dev/null; then
    PM=$(command -v dnf || command -v yum)
    MAJ="${VERSION_ID%%.*}"
    $PM install -y "https://repo.zabbix.com/zabbix/${ZBX_MAJOR}/rhel/${MAJ}/x86_64/zabbix-release-latest-${ZBX_MAJOR}.el${MAJ}.noarch.rpm" || true
    $PM install -y zabbix-agent2
  else
    echo "Unbekannte Linux-Distribution."; exit 1
  fi
  write_conf /etc/zabbix/zabbix_agent2.conf "$META"
  if command -v apt-get >/dev/null; then
    # Zusatz-Checks: offene Updates, Sicherheits-Updates, Neustart noetig
    mkdir -p /etc/zabbix/zabbix_agent2.d
    cat > /etc/zabbix/zabbix_agent2.d/homelab-updates.conf <<'CONF'
UserParameter=homelab.alive,echo 1
UserParameter=homelab.net.rx,IF=$(ip route show default | awk '/default/{print $5; exit}'); grep -E "^ *$IF:" /proc/net/dev | sed 's/^[^:]*://' | awk '{print $1}'
UserParameter=homelab.net.tx,IF=$(ip route show default | awk '/default/{print $5; exit}'); grep -E "^ *$IF:" /proc/net/dev | sed 's/^[^:]*://' | awk '{print $9}'
UserParameter=updates.count,apt-get -s upgrade 2>/dev/null | grep -c '^Inst '
UserParameter=updates.security,apt-get -s upgrade 2>/dev/null | grep '^Inst ' | grep -c -i security
UserParameter=updates.reboot,[ -f /var/run/reboot-required ] && echo 1 || echo 0
UserParameter=updates.list,apt-get -s upgrade 2>/dev/null | awk '/^Inst /{n++; if(n<=8){s=($0 ~ /[Ss]ecurity/)?"*":""; printf "%s%s%s", sep, $2, s; sep=", "}} END{if(n>8) printf " (+%d weitere)", n-8; print ""}'
UserParameter=homelab.update.status,/usr/local/bin/homelab-update.sh status
CONF
    # Paketlisten regelmaessig auffrischen, sonst zaehlt 'updates.count' veraltete Listen (alle 6 Stunden, zeitversetzt)
    command -v cron >/dev/null || apt-get install -y cron || true
    AMIN=$(( $(hostname | cksum | cut -d' ' -f1) % 60 ))
    echo "$AMIN */6 * * * root /usr/bin/apt-get update -qq >/dev/null 2>&1" > /etc/cron.d/homelab-apt-update
    # Update-Skript (nur 'status' ohne Rechte, 'start' nur ueber sudo und nur mit --update-button)
    cat > /usr/local/bin/homelab-update.sh <<'SCRIPT'
#!/usr/bin/env bash
# homelab-update.sh start|status
LOG=/var/log/homelab-update.log
LOCK=/run/homelab-update.lock
running() { [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; }
case "${1:-}" in
  start)
    [ "$(id -u)" -ne 0 ] && { echo "Nur als root"; exit 1; }
    if running; then echo "Update laeuft bereits auf $(hostname)."; exit 0; fi
    setsid nohup bash "$0" run >/dev/null 2>&1 &
    echo "Update gestartet auf $(hostname). Fortschritt: Latest data -> 'Update status'."
    ;;
  run)
    echo $$ > "$LOCK"
    {
      echo "== Start: $(date '+%F %T')"
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get -y -o Dpkg::Options::=--force-confold upgrade
      RC=$?
      echo "== Ende: $(date '+%F %T') (Code $RC)"
      [ -f /var/run/reboot-required ] && echo "== NEUSTART NOETIG"
    } > "$LOG" 2>&1
    rm -f "$LOCK"
    ;;
  status)
    if running; then echo "LAEUFT ..."; tail -n 2 "$LOG" 2>/dev/null
    elif [ -f "$LOG" ]; then tail -n 3 "$LOG"
    else echo "Noch kein Update ueber Zabbix gestartet."; fi
    ;;
  *) echo "Aufruf: $0 start|status"; exit 1 ;;
esac
SCRIPT
    chown root:root /usr/local/bin/homelab-update.sh
    chmod 755 /usr/local/bin/homelab-update.sh
    # Knopf "Updates installieren": nur mit --update-button
    if [ "$UPDATE_BUTTON" = "1" ]; then
      command -v sudo >/dev/null || apt-get install -y sudo
      echo 'zabbix ALL=(root) NOPASSWD: /usr/local/bin/homelab-update.sh start' > /etc/sudoers.d/zabbix-homelab-update.tmp
      if visudo -cf /etc/sudoers.d/zabbix-homelab-update.tmp >/dev/null; then
        chmod 440 /etc/sudoers.d/zabbix-homelab-update.tmp
        mv /etc/sudoers.d/zabbix-homelab-update.tmp /etc/sudoers.d/zabbix-homelab-update
        echo 'UserParameter=homelab.update.run,sudo /usr/local/bin/homelab-update.sh start' > /etc/zabbix/zabbix_agent2.d/homelab-update-run.conf
        echo "Update-Knopf aktiviert."
      else
        rm -f /etc/sudoers.d/zabbix-homelab-update.tmp
        echo "FEHLER: sudo-Regel ungueltig, Update-Knopf nicht aktiviert."
      fi
    else
      rm -f /etc/sudoers.d/zabbix-homelab-update /etc/zabbix/zabbix_agent2.d/homelab-update-run.conf
    fi
  fi
  # Speedtest (Internet-Geschwindigkeit) - alle 6 Stunden, mit NO_SPEEDTEST=1 ueberspringen
  if command -v apt-get >/dev/null && [ "${NO_SPEEDTEST:-0}" != "1" ]; then
    apt-get install -y speedtest-cli jq cron || echo "Hinweis: Speedtest-Pakete nicht installierbar, ueberspringe."
    if command -v speedtest-cli >/dev/null; then
      mkdir -p /var/lib/homelab; chmod 755 /var/lib/homelab
      cat > /usr/local/bin/homelab-speedtest.sh <<'SCRIPT'
#!/usr/bin/env bash
OUT=/var/lib/homelab/speedtest.json
speedtest-cli --json > "$OUT.tmp" 2>/dev/null && mv "$OUT.tmp" "$OUT" && chmod 644 "$OUT"
SCRIPT
      chmod +x /usr/local/bin/homelab-speedtest.sh
      MIN=$(( $(hostname | cksum | cut -d' ' -f1) % 60 ))
      HOUR=$(( $(hostname | cksum | cut -d' ' -f1) % 6 ))
      echo "$MIN $HOUR,$((HOUR+6)),$((HOUR+12)),$((HOUR+18)) * * * root /usr/local/bin/homelab-speedtest.sh" > /etc/cron.d/homelab-speedtest
      cat > /etc/zabbix/zabbix_agent2.d/homelab-speedtest.conf <<'CONF'
UserParameter=speedtest.download,jq -r '.download' /var/lib/homelab/speedtest.json
UserParameter=speedtest.upload,jq -r '.upload' /var/lib/homelab/speedtest.json
UserParameter=speedtest.ping,jq -r '.ping' /var/lib/homelab/speedtest.json
CONF
      nohup /usr/local/bin/homelab-speedtest.sh >/dev/null 2>&1 &
    fi
  fi
  systemctl enable zabbix-agent2
  systemctl restart zabbix-agent2
  command -v docker >/dev/null && usermod -aG docker zabbix && systemctl restart zabbix-agent2 || true
  ;;
Darwin)
  META="macOS"
  ARCH="$(uname -m)"; [ "$ARCH" = "arm64" ] && ARCH="arm64" || ARCH="amd64"
  PKG="/tmp/zabbix_agent2.pkg"
  URL="https://cdn.zabbix.com/zabbix/binaries/stable/${ZBX_MAJOR}/${ZBX_VERSION}/zabbix_agent2-${ZBX_VERSION}-macos-${ARCH}-openssl.pkg"
  curl -fSL "$URL" -o "$PKG" || { echo "Download fehlgeschlagen. Pruefe Version/URL auf https://www.zabbix.com/download_agents"; exit 1; }
  installer -pkg "$PKG" -target /
  CONF=$(ls /usr/local/etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf 2>/dev/null | head -1)
  [ -z "$CONF" ] && { echo "Config nicht gefunden."; exit 1; }
  write_conf "$CONF" "$META"
  PLIST=$(ls /Library/LaunchDaemons/com.zabbix.zabbix_agent2.plist 2>/dev/null || true)
  [ -n "$PLIST" ] && { launchctl unload "$PLIST" 2>/dev/null || true; launchctl load -w "$PLIST"; }
  ;;
*) echo "System $OS wird von diesem Skript nicht unterstuetzt (Windows: install.ps1)."; exit 1;;
esac
echo "Fertig. Agent meldet sich bei $SERVER als '$HOSTNAME_ARG' (Metadata: $META)."
