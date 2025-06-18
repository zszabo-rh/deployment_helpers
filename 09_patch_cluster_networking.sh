set -eu
source config.env

HOST_NETWORK=$(curl -s ${API}/clusters/${CLUSTER_ID} | jq '.host_networks[0].cidr' | sed 's/^"//' | sed 's/"$//')

export API_NAME=$(curl -s ${API}/clusters/${CLUSTER_ID} | jq '.hosts[0].domain_name_resolutions' |sed 's/\\"/"/g' | sed 's/^"//' | sed 's/"$//' | jq '.resolutions[0].domain_name' | sed 's/^"//' | sed 's/"$//')
export APPS_NAME=$(echo $API_NAME | sed 's/api/*.apps/' | sed 's/^"//' | sed 's/"$//')

if [ "${MASTERS}" -eq 1 ]; then
    echo "[INFO] Single node (SNO) detected, patching VIP and networks..."
    VM_DOMAIN=$(virsh list --all --name | grep extraworker)
    MAC=$(virsh dumpxml $VM_DOMAIN | xmllint --xpath "//interface[source/@bridge='$BRIDGE']/mac/@address" - 2>/dev/null | sed 's/ address="\([^"]*\)"/\1/')
    API_VIP=$(virsh net-dumpxml $BRIDGE | xmllint --xpath "//host[@id][contains(@id, '$MAC')]/@ip" - | cut -d '"' -f2)

    curl -s -X PATCH -H "Content-Type: application/json" \
        -d "{\"service_networks\":[{\"cidr\":\"fd02::/112\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"machine_networks\":[{\"cidr\":\"${HOST_NETWORK}\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"cluster_networks\":[{\"cidr\": \"fd01::/48\",\"cluster_id\":\"${CLUSTER_ID}\",\"host_prefix\": 64}]}" \
        ${API}/clusters/${CLUSTER_ID} >/dev/null 2>&1
else
    echo "[INFO] Multi-node (HA) detected, patching VIPs and networks..."
    export API_VIP=$(echo $HOST_NETWORK | cut -d '/' -f1)5
    export INGRESS_VIP=$(echo $HOST_NETWORK | cut -d '/' -f1)6
    echo "$INGRESS_VIP $APPS_NAME" >> /etc/hosts

    curl -s -X PATCH -H "Content-Type: application/json" \
        -d "{\"service_networks\":[{\"cidr\":\"fd02::/112\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"cluster_networks\":[{\"cidr\": \"fd01::/48\",\"cluster_id\":\"${CLUSTER_ID}\",\"host_prefix\": 64}]}" \
        ${API}/clusters/${CLUSTER_ID} >/dev/null 2>&1

    curl -s -X PATCH -H "Content-Type: application/json" \
        -d "{\"api_vips\":[{\"ip\":\"${API_VIP}\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"ingress_vips\":[{\"ip\":\"${INGRESS_VIP}\",\"cluster_id\":\"${CLUSTER_ID}\"}]}" \
        ${API}/clusters/${CLUSTER_ID} >/dev/null 2>&1
fi

echo "$API_VIP $API_NAME" >> /etc/hosts

echo "[INFO] Cluster networking patch complete."