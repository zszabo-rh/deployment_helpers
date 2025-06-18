set -eu
source config.env

echo "[INFO] Creating certificate directory..."
mkdir -p /opt/registry/certs/ >/dev/null 2>&1

cert_c="US"
cert_s="NC"
cert_l="Raleigh"
cert_o="RedHat"
cert_ou="Testing"
cert_cn="${REGISTRY_HOSTNAME}"

echo "[INFO] Generating self-signed certificate for ${REGISTRY_HOSTNAME}..."
openssl req \
    -newkey rsa:4096 \
    -nodes \
    -sha256 \
    -keyout /etc/pki/ca-trust/source/anchors/domain.key \
    -x509 \
    -days 365 \
    -out /opt/registry/certs/domain.crt \
    -addext "subjectAltName = DNS:${REGISTRY_HOSTNAME}" \
    -subj "/C=${cert_c}/ST=${cert_s}/L=${cert_l}/O=${cert_o}/OU=${cert_ou}/CN=${cert_cn}" \
    >/dev/null 2>&1

echo "[INFO] Updating CA trust with new certificate..."
yes | cp -f /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/edge-registry.crt >/dev/null 2>&1
update-ca-trust extract >/dev/null 2>&1

echo "[INFO] Certificate setup complete."