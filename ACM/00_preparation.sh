set -eu
source config.env

echo "[INFO] Removing old SSH keys..."
rm -rf ~/.ssh/${CLUSTER_NAME}* >/dev/null 2>&1
echo "[INFO] Generating new SSH key..."
ssh-keygen -t rsa -f ~/.ssh/${CLUSTER_NAME} -P '' -q

echo "[INFO] Installing required packages..."
dnf install -y wget git make jq -q >/dev/null

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

echo "[INFO] Loading SSH key and pull secret..."
echo "export SSH_KEY=$(cat ~/.ssh/${CLUSTER_NAME}.pub)" >> config.env
echo "export PULL_SECRET_STR=$(jq -c . pull_secret.json | jq -c -R .)" >> config.env

echo "[INFO] Preparation complete."