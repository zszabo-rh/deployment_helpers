set -eu
source config.env

mkdir -p /opt/registry/certs/
cert_c="US"
cert_s="NC"
cert_l="Raleigh"
cert_o="RedHat"
cert_ou="Testing"
cert_cn="${REGISTRY_HOSTNAME}"
openssl req \
    -newkey rsa:4096 \
    -nodes \
    -sha256 \
    -keyout /etc/pki/ca-trust/source/anchors/domain.key \
    -x509 \
    -days 365 \
    -out /opt/registry/certs/domain.crt \
    -addext "subjectAltName = DNS:${REGISTRY_HOSTNAME}" \
    -subj "/C=${cert_c}/ST=${cert_s}/L=${cert_l}/O=${cert_o}/OU=${cert_ou}/CN=${cert_cn}"
# Update the registry node’s ca-trust with the new certificate
yes | cp -f /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/edge-registry.crt
update-ca-trust extract
