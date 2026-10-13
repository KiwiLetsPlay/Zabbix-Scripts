#!/usr/bin/env bash
# Zeigt offene Updates und installiert sie nach Rueckfrage (Ubuntu/Debian)
# Aufruf: ./update.sh          (zeigt an und fragt)
#         ./update.sh --list   (nur anzeigen)
#         ./update.sh --yes    (ohne Rueckfrage installieren)
set -u
[ "$(id -u)" -ne 0 ] && exec sudo "$0" "$@"

echo "== Paketlisten aktualisieren =="
apt-get update -qq

LIST=$(apt-get -s upgrade | grep '^Inst ')
COUNT=$(printf '%s\n' "$LIST" | grep -c . || true)
SEC=$(printf '%s\n' "$LIST" | grep -ci security || true)

if [ "$COUNT" -eq 0 ]; then
  echo "Alles aktuell auf $(hostname)."
  [ -f /var/run/reboot-required ] && echo "HINWEIS: Neustart noetig."
  exit 0
fi

echo
echo "== $(hostname): $COUNT Updates ($SEC davon Sicherheit) =="
apt list --upgradable 2>/dev/null | tail -n +2
echo

[ "${1:-}" = "--list" ] && exit 0

if [ "${1:-}" != "--yes" ]; then
  read -r -p "Jetzt installieren? [j/N] " A
  [ "$A" = "j" ] || [ "$A" = "J" ] || { echo "Abgebrochen."; exit 0; }
fi

apt-get upgrade -y
echo
echo "== Fertig =="
[ -f /var/run/reboot-required ] && echo "HINWEIS: Neustart noetig (sudo reboot)." || echo "Kein Neustart noetig."
