set -eu
source config.env

echo "[INFO] Disabling IPv4 on interface ${MAIN_INTERFACE}..."
nmcli con modify ${MAIN_INTERFACE} ipv4.method disabled >/dev/null 2>&1
nmcli con down ${MAIN_INTERFACE} >/dev/null 2>&1 && nmcli con up ${MAIN_INTERFACE} >/dev/null 2>&1

echo "[INFO] IPv4 disabled and interface restarted."