set -eu

echo "[INFO] Enabling and starting firewalld..."
systemctl enable firewalld >/dev/null 2>&1 && sudo systemctl start firewalld >/dev/null 2>&1
firewall-cmd --permanent --zone=public --add-port={80/tcp,443/tcp,8090/tcp,8080/tcp,8888/tcp,5000/tcp,8443/tcp} >/dev/null 2>&1
firewall-cmd --permanent --zone=libvirt --add-port={80/tcp,443/tcp,8090/tcp,8080/tcp,8888/tcp,5000/tcp,8443/tcp} >/dev/null 2>&1
sudo firewall-cmd --reload >/dev/null 2>&1

echo "[INFO] Firewall configuration complete."