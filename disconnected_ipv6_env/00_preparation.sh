set -eu
source config.env

echo "[INFO] Removing old SSH keys..."
rm -rf ~/.ssh/${CLUSTER_NAME}* >/dev/null 2>&1
echo "[INFO] Generating new SSH key..."
ssh-keygen -t rsa -f ~/.ssh/${CLUSTER_NAME} -P '' -q

echo "[INFO] Installing required packages..."
dnf install -y nginx wget git make python3 podman httpd httpd-tools jq skopeo -q >/dev/null
wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq

curl -L https://mirror.openshift.com/pub/openshift-v4/amd64/clients/ocp/latest/openshift-client-linux-amd64-rhel8.tar.gz | sudo tar -U -C /usr/local/bin -xzf - 

OFFLINE_ACCESS_TOKEN=${OFFLINE_ACCESS_TOKEN}

echo "[INFO] Requesting OpenShift access token..."
TOKEN=$(curl \
--silent \
--data-urlencode "grant_type=refresh_token" \
--data-urlencode "client_id=cloud-services" \
--data-urlencode "refresh_token=${OFFLINE_ACCESS_TOKEN}" \
https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | \
jq -r .access_token)

echo "[INFO] Downloading pull secret..."
curl -s -X POST "https://api.stage.openshift.com/api/accounts_mgmt/v1/access_token" \
  -H "accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  --output pull_secret.json

echo "[INFO] Updating pull secret with local auth strings..."
jq ".auths += $LOCAL_AUTHSTRING" < pull_secret.json > pull_secret_up1.json
jq ".auths += $LOCAL_AUTHSTRING_IP" < pull_secret_up1.json > pull_secret_up2.json
rm -rf pull_secret.json >/dev/null 2>&1
mv pull_secret_up2.json pull_secret.json >/dev/null 2>&1
rm -rf pull_secret_up1.json >/dev/null 2>&1

echo "[INFO] Loading SSH key and pull secret..."
echo "export SSH_KEY=\"$(cat ~/.ssh/${CLUSTER_NAME}.pub)\"" >> config.env
echo "export PULL_SECRET_STR=$(jq -c . pull_secret.json | jq -c -R .)" >> config.env

echo "[INFO] Cloning assisted-service repository..."
git clone -q https://github.com/openshift/assisted-service.git >/dev/null 2>&1

echo "[INFO] Cloning dev-scripts repository..."
git clone -q https://github.com/openshift-metal3/dev-scripts >/dev/null 2>&1

echo "[INFO] Preparation complete."