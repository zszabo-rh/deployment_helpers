set -eu
source ${WORKDIR}/config.env

# https://github.com/openshift/assisted-service/blob/780deffb6a3555cba0853db088647607b40093f2/deploy/podman/README-disconnected.md

export SSH_KEY=$(cat ~/.ssh/cluster.pub)
export PULL_SECRET_STR=$(jq -c . /${WORKDIR}/pull_secret.json | jq -c -R .)

# Register new cluster
export CLUSTER_ID=$(curl -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"${CLUSTER_NAME}\",\"control_plane_count\":${MASTERS},\"openshift_version\":\"${OCP_VER}\",\"pull_secret\":${PULL_SECRET_STR},\"base_dns_domain\":\"redhat.com\"}" \
    ${API}/clusters | jq '.id' | sed 's/^"//' | sed 's/"$//')
echo "export CLUSTER_ID=${CLUSTER_ID}" >> config.env

# Register InfraEnv
export INFRA_ENV_ID=$(curl -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"${CLUSTER_NAME}_infra-env\",\"pull_secret\":${PULL_SECRET_STR},\"cluster_id\":\"${CLUSTER_ID}\",\"openshift_version\":\"${OCP_VER}\"}" \
    ${API}/infra-envs | jq '.id'| sed 's/^"//' | sed 's/"$//')
echo "export INFRA_ENV_ID=${INFRA_ENV_ID}" >> config.env

# Patch cluster with SSH key
curl -X PATCH -H "Content-Type: application/json" \
    -d "{\"ssh_public_key\":\"${SSH_KEY}\"}" \
    ${API}/clusters/${CLUSTER_ID}

# Create registry.conf
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

# Create discovery-ignition.json
base64 -w0 registry.conf > registry.conf.b64
base64 -w0 tls-ca-bundle.pem  > ca.crt.b64

rm -rf discovery-ignition.json

cat >> discovery-ignition.json << EOF
{"ignition_config_override": "{\"ignition\": {\"version\": \"3.1.0\"}, \"passwd\": {\"users\": [{\"groups\":[\"sudo\"],\"name\":\"core\",\"passwordHash\": \"!\",\"sshAuthorizedKeys\":[\"${SSH_KEY}\"]}]}, \"storage\": {\"files\": [{\"path\": \"/etc/containers/registries.conf\", \"mode\": 420, \"overwrite\": true, \"user\": { \"name\": \"root\"},\"contents\": {\"source\": \"data:text/plain;base64,$(cat registry.conf.b64)\"}}, {\"path\": \"/etc/pki/ca-trust/source/anchors/domain.crt\", \"mode\": 420, \"overwrite\": true, \"user\": { \"name\": \"root\"}, \"contents\": {\"source\":\"data:text/plain;base64,$(cat ca.crt.b64)\"}}]}}"}
EOF

# Patch ignition
curl \
    --header "Content-Type: application/json" \
    --request PATCH \
    --data @discovery-ignition.json \
"${API}/infra-envs/$INFRA_ENV_ID"

export IDMS=\{\"imageDigestSources\":[\{\"source\":\"quay.io/openshift-release-dev/ocp-v4.0-art-dev\",\"mirrors\":[\"${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4\"]\},\{\"source\":\"quay.io/openshift-release-dev/ocp-release\",\"mirrors\":[\"${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4\"]\}]\}
export TRUST_BUNDLE=$(jq -Rsc '{additionalTrustBundle: .}' /${WORKDIR}/tls-ca-bundle.pem)
export INSTALL_PATCH=$(jq -cn --argjson idms "$IDMS" --argjson trust "$TRUST_BUNDLE" '$idms + $trust' | jq -Rc .)

curl \
  --header "Content-Type: application/json" \
  --request PATCH \
  --data "$INSTALL_PATCH" \
"${API}/clusters/$CLUSTER_ID/install-config"

# Download discovery ISO
rm -rf $ISO_PATH
IMAGE_URL=$(curl -s ${API}/infra-envs/${INFRA_ENV_ID}/downloads/image-url | jq '.url' | sed 's/full/minimal/' | sed 's/^"//' | sed 's/"$//')
wget -O ${ISO_PATH} ${IMAGE_URL}
