#!/usr/bin/env bash
# Zabbix Agent 2 Installer fuer Linux und macOS (erkennt das System automatisch)
# Aufruf: sudo ./install.sh <ZABBIX-SERVER-IP> [HOSTNAME]
set -euo pipefail

SERVER="${1:-}"
HOSTNAME_ARG="${2:-$(hostname)}"
ZBX_MAJOR="7.0"
ZBX_VERSION="${ZBX_VERSION:-7.0.31}"   # nur fuer macOS-Paket noetig

[ -z "$SERVER" ] && { echo "Aufruf: sudo $0 <ZABBIX-SERVER-IP> [HOSTNAME]"; exit 1; }
[ "$(id -u)" -ne 0 ] && { echo "Bitte mit sudo starten."; exit 1; }

OS="$(uname -s)"
CONF_APPEND="
Server=${SERVER}
ServerActive=${SERVER}
Hostname=${HOSTNAME_ARG}
"

write_conf() { # $1 = conf-Datei, $2 = Metadata
  cp -n "$1" "$1.bak" 2>/dev/null || true
  sed -i.tmp -E '/^(Server|ServerActive|Hostname|HostMetadata)=/d' "$1" && rm -f "$1.tmp"
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
CONF
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
