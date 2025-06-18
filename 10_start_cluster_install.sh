set -eu
source config.env

echo "[INFO] Starting cluster installation..."
curl -s -X POST ${API}/clusters/${CLUSTER_ID}/actions/install >/dev/null 2>&1

echo "[INFO] Fetching cluster events..."


echo "[INFO] Check cluster events with following command:"
echo "\n  curl --silent ${API}/events?cluster_id=${CLUSTER_ID} | jq"
