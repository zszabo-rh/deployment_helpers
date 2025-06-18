set -eu
source config.env

# Start install
curl -X POST ${API}/clusters/${CLUSTER_ID}/actions/install
curl ${API}/events\?cluster_id\=${CLUSTER_ID} | jq
