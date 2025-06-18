set -eu
source config.env

# https://docs.google.com/document/d/1TE8mByRLVDfyF79eEOyf4KiqEJ90tIhRspzq6Of-vec/edit?tab=t.0#heading=h.mwhk5oz52qnm

mkdir -p /opt/registry/{auth,certs,data}
cp /etc/pki/ca-trust/source/anchors/domain.key /opt/registry/certs/
cp /opt/registry/certs/domain.crt /${WORKDIR}/tls-ca-bundle.pem

# Create an htpasswd file in /opt/registry/auth for the container to use
htpasswd -bBc /opt/registry/auth/htpasswd $LOCAL_REG_USER $LOCAL_REG_PASS

podman stop registry && podman rm registry
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
  docker.io/library/registry:2
podman start registry
podman login -u ${LOCAL_REG_USER} -p ${LOCAL_REG_PASS} ${REGISTRY_HOSTNAME}:${REG_PORT} --tls-verify=false   

oc adm release mirror \
   -a {WORDIR}/pull_secret.json \
   --from quay.io/openshift-release-dev/ocp-release:${OCP_VER}-x86_64 \
   --to-release-image ${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4:${OCP_VER}-x86_64 \
   --print-mirror-instructions idms \
   --to ${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4 2>&1 | tee /tmp/oc_adm_mirror.log
oc adm release extract -a {WORDIR}/pull_secret.json --command=openshift-install "${REGISTRY_HOSTNAME}:${REG_PORT}/ocp4/openshift4:${OCP_VER}-x86_64"
rm -rf /usr/local/bin/openshift-install
mv openshift-install /usr/local/bin/openshift-install

# !!! Note the imageContentSources at the end of the output !!! will be used during install-config patch later! (imageDigestSources) 

skopeo copy --authfile {WORDIR}/pull_secret.json \
--remove-signatures --dest-tls-verify=false \
docker://registry.redhat.io/ubi8/ubi:latest \
docker://${REGISTRY_HOSTNAME}:${REG_PORT}/ubi8/ubi:latest

skopeo copy --authfile {WORDIR}/pull_secret.json \
--remove-signatures --dest-tls-verify=false \
docker://registry.redhat.io/ubi9/ubi@sha256:20f695d2a91352d4eaa25107535126727b5945bff38ed36a3e59590f495046f0 \
docker://${REGISTRY_HOSTNAME}:${REG_PORT}/ubi9/ubi

for image in \
  edge-infrastructure/assisted-installer-agent:latest \
  edge-infrastructure/assisted-installer:latest \
  edge-infrastructure/assisted-installer-controller:latest; do \
  skopeo copy --remove-signatures --dest-tls-verify=false \
    --authfile {WORDIR}/pull_secret.json \
    docker://quay.io/${image} \
    docker://${REGISTRY_HOSTNAME}:${REG_PORT}/${image};
done
