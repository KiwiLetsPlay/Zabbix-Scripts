#!/usr/bin/env bash
# Entfernt den Zabbix Agent 2 samt Homelab-Checks (Linux und macOS)
# Aufruf: sudo ./uninstall.sh
set -u
[ "$(id -u)" -ne 0 ] && { echo "Bitte mit sudo starten."; exit 1; }

case "$(uname -s)" in
Linux)
  systemctl stop zabbix-agent2 2>/dev/null
  systemctl disable zabbix-agent2 2>/dev/null
  if command -v apt-get >/dev/null; then
    apt-get purge -y zabbix-agent2 zabbix-release 2>/dev/null
    rm -f /etc/apt/sources.list.d/zabbix*.list /etc/apt/sources.list.d/zabbix*.sources
    apt-get autoremove -y 2>/dev/null
  elif command -v dnf >/dev/null || command -v yum >/dev/null; then
    PM=$(command -v dnf || command -v yum)
    $PM remove -y zabbix-agent2 zabbix-release 2>/dev/null
  fi
  rm -rf /etc/zabbix /var/log/zabbix
  rm -f /etc/cron.d/homelab-speedtest /usr/local/bin/homelab-speedtest.sh
  rm -rf /var/lib/homelab
  # (speedtest-cli, jq und cron bleiben installiert, falls du sie anderweitig nutzt)
  ;;
Darwin)
  for P in /Library/LaunchDaemons/com.zabbix.zabbix_agent2.plist; do
    [ -f "$P" ] && { launchctl unload "$P" 2>/dev/null; rm -f "$P"; }
  done
  rm -rf /usr/local/etc/zabbix /etc/zabbix /usr/local/sbin/zabbix_agent2 /usr/local/bin/zabbix_get /usr/local/bin/zabbix_sender
  for ID in $(pkgutil --pkgs | grep -i zabbix); do pkgutil --forget "$ID"; done
  ;;
*) echo "System nicht unterstuetzt (Windows: uninstall.ps1)."; exit 1;;
esac
echo "Zabbix Agent entfernt. Den Host in Zabbix loeschst du von Hand: Data collection -> Hosts."
