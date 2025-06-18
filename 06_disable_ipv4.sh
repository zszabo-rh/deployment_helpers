set -eu
source config.env

nmcli con modify ${MAIN_INTERFACE} ipv4.method disabled
nmcli con down ${MAIN_INTERFACE} && nmcli con up ${MAIN_INTERFACE}
