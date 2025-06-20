set -eu
source config.env

echo "[INFO] Preparing certificates and authentication for local registry..."
mkdir -p /opt/registry/{auth,certs,data} >/dev/null 2>&1
cp /etc/pki/ca-trust/source/anchors/domain.key /opt/registry/certs/ >/dev/null 2>&1
cp /opt/registry/certs/domain.crt ./tls-ca-bundle.pem >/dev/null 2>&1
htpasswd -bBc /opt/registry/auth/htpasswd $LOCAL_REG_USER $LOCAL_REG_PASS >/dev/null 2>&1

echo "[INFO] Creating new registry container..."
podman stop registry >/dev/null 2>&1 || true
podman rm registry >/dev/null 2>&1 || true
podman create \
  --name registry \
  --network host \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
  -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt" \
  -e "REGISTRY_HTTP_TLS_KEY=/certs/domain.key" \
  -e "REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true" \
  -v /opt/registry/data:/var/lib/registry:z \
  -v /opt/registry/auth:/auth:z \
  -v /opt/registry/certs:/certs:z \
  docker.io/library/registry:2 >/dev/null 2>&1

podman start registry >/dev/null 2>&1

echo "[INFO] Logging into local registry..."
podman login -u ${LOCAL_REG_USER} -p ${LOCAL_REG_PASS} ${REGISTRY_HOSTNAME}:${REG_PORT} --tls-verify=false >/dev/null 2>&1

echo "[INFO] Mirroring OpenShift release images to local registry..."
oc adm release mirror \
   -a ./pull_secret.json \
   --from quay.io/openshift-release-dev/ocp-release:${OCP_VER}-x86_64 \
   --to-release-image ${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4:${OCP_VER}-x86_64 \
   --print-mirror-instructions idms \
   --to ${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4 2>&1

echo "[INFO] Installing openshift-install binary..."
oc adm release extract -a ./pull_secret.json --command=openshift-install "${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4:${OCP_VER}-x86_64" >/dev/null 2>&1
rm -rf /usr/local/bin/openshift-install >/dev/null 2>&1
mv openshift-install /usr/local/bin/openshift-install >/dev/null 2>&1

echo "[INFO] Copying UBI8 image to local registry..."
skopeo copy --authfile ./pull_secret.json \
--remove-signatures --dest-tls-verify=false \
docker://registry.redhat.io/ubi8/ubi:latest \
docker://${REGISTRY_HOSTNAME}:${REG_PORT}/ubi8/ubi:latest >/dev/null 2>&1

echo "[INFO] Copying UBI9 image to local registry..."
skopeo copy --authfile ./pull_secret.json \
--remove-signatures --dest-tls-verify=false \
docker://registry.redhat.io/ubi9/ubi@sha256:20f695d2a91352d4eaa25107535126727b5945bff38ed36a3e59590f495046f0 \
docker://${REGISTRY_HOSTNAME}:${REG_PORT}/ubi9/ubi >/dev/null 2>&1

echo "[INFO] Copying postgresql image to local registry..."
skopeo copy --authfile ./pull_secret.json \
--remove-signatures --dest-tls-verify=false \
docker://quay.io/sclorg/postgresql-12-c8s:latest \
docker://${REGISTRY_HOSTNAME}:${REG_PORT}/sclorg/postgresql-12-c8s:latest >/dev/null 2>&1

echo "[INFO] Copying assisted-installer images to local registry..."
for image in \
  edge-infrastructure/assisted-installer-ui:latest \
  edge-infrastructure/assisted-image-service:latest \
  edge-infrastructure/assisted-service:latest \
  edge-infrastructure/assisted-installer-agent:latest \
  edge-infrastructure/assisted-installer:latest \
  edge-infrastructure/assisted-installer-controller:latest; do
  skopeo copy --remove-signatures --dest-tls-verify=false \
    --authfile ./pull_secret.json \
    docker://quay.io/${image} \
    docker://${REGISTRY_HOSTNAME}:${REG_PORT}/${image} >/dev/null 2>&1
done

echo "[INFO] Registry setup and image mirroring complete."