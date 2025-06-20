source config.env
WORKDIR=$(pwd)

echo "[INFO] Setting up web server for RHCOS images..."
sudo mkdir -p /usr/share/nginx/html/pub/openshift-v4/amd64/dependencies/rhcos/4.18/${RHCOS_VER} >/dev/null 2>&1
cd /usr/share/nginx/html/pub/openshift-v4/amd64/dependencies/rhcos/4.18/${RHCOS_VER}
sudo wget -q https://mirror.openshift.com/pub/openshift-v4/amd64/dependencies/rhcos/4.18/${RHCOS_VER}/rhcos-${RHCOS_VER}-x86_64-live.x86_64.iso >/dev/null 2>&1
sudo wget -q https://mirror.openshift.com/pub/openshift-v4/amd64/dependencies/rhcos/4.18/${RHCOS_VER}/sha256sum.txt >/dev/null 2>&1
sudo wget -q https://mirror.openshift.com/pub/openshift-v4/amd64/dependencies/rhcos/4.18/${RHCOS_VER}/rhcos-id.txt >/dev/null 2>&1
export RHCOS_ID=$(cat rhcos-id.txt)
sudo systemctl enable nginx --now >/dev/null 2>&1

echo "[INFO] Cloning assisted-service repository..."
cd ${WORKDIR}
rm -rf ./assisted-service >/dev/null 2>&1
git clone -q https://github.com/openshift/assisted-service.git >/dev/null 2>&1
cd assisted-service/deploy/podman/

echo "[INFO] Updating URLs, IPs, and image versions in configmap..."
export REGISTRY_HOST_IP=[${REGISTRY_HOST_IP6}]
cp configmap-disconnected.yml configmap-disconnected.yml.bak >/dev/null 2>&1
sed "s/<IP address of assisted installer host>/${REGISTRY_HOST_IP}/" -i configmap-disconnected.yml
sed "s/<IP address of iso mirror>/${REGISTRY_HOST_IP}/" -i configmap-disconnected.yml
sed "s/<container image registry server:port>/${REGISTRY_HOSTNAME}:${REG_PORT}/" -i configmap-disconnected.yml
sed "s/410.84.202205191234-0/${RHCOS_ID}/" -i configmap-disconnected.yml
sed "s|4.10/4.10.16/rhcos-4.10.16-x86_64-live.x86_64.iso|4.18/${RHCOS_VER}/rhcos-${RHCOS_VER}-x86_64-live.x86_64.iso|" -i configmap-disconnected.yml
sed "s|openshift4:4.10.22-x86_64|openshift4:${OCP_VER}-x86_64|" -i configmap-disconnected.yml
sed "s/4.10.22/${OCP_VER}/" -i configmap-disconnected.yml
sed "s/4.10/4.18/" -i configmap-disconnected.yml
sed "s|openshift-v4/dependencies|openshift-v4/amd64/dependencies|" -i configmap-disconnected.yml

echo "[INFO] Changing pod to host networking..."
grep 'hostNetwork' pod-persistent-disconnected.yml >/dev/null 2>&1 || sed -i 's/spec:/spec:\n  hostNetwork: true/' pod-persistent-disconnected.yml
sed -i '/    ports:/d' pod-persistent-disconnected.yml
sed -i '/    - hostPort:/d' pod-persistent-disconnected.yml
sed -i 's/quay.io/${REGISTRY_HOSTNAME}:${REG_PORT}/g' pod-persistent-disconnected.yml

echo "[INFO] Inserting certificate to configmap..."
yes | cp -f ${WORKDIR}/tls-ca-bundle.pem . >/dev/null 2>&1

awk '
  FILENAME == ARGV[1] {
    cert_lines[++cert_count] = $0
    next
  }
  {
    if ($1 == "tls-ca-bundle.pem:" && $2 == "|") {
      print
      in_cert_block = 1
      getline
      indent = match($0, /[^ ]/) - 1
      for (i = 1; i <= cert_count; i++) {
        printf "%*s%s\n", indent, "", cert_lines[i]
      }
      # Skip old cert block
      while (getline) {
        if ($0 ~ /^[^[:space:]]/) { print $0; break }
        if ($0 ~ /^[[:space:]]{2,}\S/) continue
      }
    } else {
      print
    }
  }
' tls-ca-bundle.pem configmap-disconnected.yml > configmap-disconnected-patched.yml

yes | cp -f ${WORKDIR}/pull_secret.json /run/user/0/containers/auth.json >/dev/null 2>&1

echo "[INFO] Stopping and removing existing assisted-installer containers and pods..."
podman stop $(podman ps -aq --filter name=assisted-installer) >/dev/null 2>&1 || true
podman rm $(podman ps -aq --filter name=assisted-installer) >/dev/null 2>&1 || true
podman volume rm config >/dev/null 2>&1 || true
podman pod rm assisted-installer >/dev/null 2>&1 || true

echo "[INFO] Running assisted installer using podman play kube..."
podman play kube --configmap configmap-disconnected-patched.yml pod-persistent-disconnected.yml >/dev/null 2>&1

cd ${WORKDIR}
echo "[INFO] Assisted installer setup complete."