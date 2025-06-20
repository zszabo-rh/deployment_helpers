set -eu
source config.env

echo "[INFO] Registering new cluster..."
export CLUSTER_ID=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"${CLUSTER_NAME}\",\"control_plane_count\":${MASTERS},\"openshift_version\":\"${OCP_VER}\",\"pull_secret\":${PULL_SECRET_STR},\"base_dns_domain\":\"${BASE_DOMAIN}\"}" \
    ${API}/clusters | jq -r '.id')
echo "export CLUSTER_ID=${CLUSTER_ID}" >> config.env

echo "[INFO] Registering InfraEnv..."
export INFRA_ENV_ID=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"${CLUSTER_NAME}_infra-env\",\"pull_secret\":${PULL_SECRET_STR},\"cluster_id\":\"${CLUSTER_ID}\",\"openshift_version\":\"${OCP_VER}\"}" \
    ${API}/infra-envs | jq -r '.id')
echo "export INFRA_ENV_ID=${INFRA_ENV_ID}" >> config.env

echo "[INFO] Patching cluster with SSH key..."
curl -s -X PATCH -H "Content-Type: application/json" \
    -d "{\"ssh_public_key\":\"${SSH_KEY}\"}" \
    ${API}/clusters/${CLUSTER_ID} >/dev/null 2>&1

echo "[INFO] Patching ignition config..."
rm -rf registry.conf
cat >> registry.conf << EOF
unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]
[[registry]]                                                                                                      
    prefix = ""                                                                                                   
    location = "quay.io/openshift-release-dev/ocp-release"      
    mirror-by-digest-only = true                                                                                  
    [[registry.mirror]]                                                                                           
    location = "${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4"
[[registry]]
    prefix = ""          
    location = "quay.io/openshift-release-dev/ocp-v4.0-art-dev"
    mirror-by-digest-only = true
    [[registry.mirror]]
    location = "${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4"
EOF

base64 -w0 registry.conf > registry.conf.b64
base64 -w0 tls-ca-bundle.pem  > ca.crt.b64

rm -rf discovery-ignition.json
cat >> discovery-ignition.json << EOF
{"ignition_config_override": "{\"ignition\": {\"version\": \"3.1.0\"}, \"passwd\": {\"users\": [{\"groups\":[\"sudo\"],\"name\":\"core\",\"passwordHash\": \"!\",\"sshAuthorizedKeys\":[\"${SSH_KEY}\"]}]}, \"storage\": {\"files\": [{\"path\": \"/etc/containers/registries.conf\", \"mode\": 420, \"overwrite\": true, \"user\": { \"name\": \"root\"},\"contents\": {\"source\": \"data:text/plain;base64,$(cat registry.conf.b64)\"}}, {\"path\": \"/etc/pki/ca-trust/source/anchors/domain.crt\", \"mode\": 420, \"overwrite\": true, \"user\": { \"name\": \"root\"}, \"contents\": {\"source\":\"data:text/plain;base64,$(cat ca.crt.b64)\"}}]}}"}
EOF

curl -s \
    --header "Content-Type: application/json" \
    --request PATCH \
    --data @discovery-ignition.json \
"${API}/infra-envs/$INFRA_ENV_ID" >/dev/null 2>&1

echo "[INFO] Patching install-config..."
export IDMS=\{\"imageDigestSources\":[\{\"source\":\"quay.io/openshift-release-dev/ocp-v4.0-art-dev\",\"mirrors\":[\"${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4\"]\},\{\"source\":\"quay.io/openshift-release-dev/ocp-release\",\"mirrors\":[\"${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4\"]\}]\}
export TRUST_BUNDLE=$(jq -Rsc '{additionalTrustBundle: .}' ./tls-ca-bundle.pem)
rm -rf install-config-override.json
cat >> install-config-override.json << EOF
$(jq -cn --argjson idms "$IDMS" --argjson trust "$TRUST_BUNDLE" '$idms + $trust' | jq -Rc .)
EOF

curl -s \
  --header "Content-Type: application/json" \
  --request PATCH \
  --data @install-config-override.json \
"${API}/clusters/$CLUSTER_ID/install-config" >/dev/null 2>&1

rm -rf $ISO_PATH >/dev/null 2>&1
while true; do
    IMAGE_URL=$(curl -s ${API}/infra-envs/${INFRA_ENV_ID}/downloads/image-url | jq -r '.url' | sed 's/full/minimal/')
    if [[ $IMAGE_URL =~ ^http ]]; then
        break
    fi
    echo "[INFO] Waiting for a valid IMAGE_URL..."
    sleep 5
done
echo "[INFO] Downloading discovery ISO..."
wget -q -O ${ISO_PATH} ${IMAGE_URL}

echo "[INFO] Cluster setup complete."