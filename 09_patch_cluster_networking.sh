set -eu
source config.env

HOST_NETWORK=$(curl -s ${API}/clusters/${CLUSTER_ID} | jq '.host_networks[0].cidr' | sed 's/^"//' | sed 's/"$//')

export API_NAME=$(curl -s ${API}/clusters/${CLUSTER_ID} | jq '.hosts[0].domain_name_resolutions' |sed 's/\\"/"/g' | sed 's/^"//' | sed 's/"$//' | jq '.resolutions[0].domain_name' | sed 's/^"//' | sed 's/"$//')
export APPS_NAME=$(echo $API_NAME | sed 's/api/*.apps/' | sed 's/^"//' | sed 's/"$//')

# VIPs and networks for HA cluster
export API_VIP=$(echo $HOST_NETWORK | cut -d '/' -f1)5
export INGRESS_VIP=$(echo $HOST_NETWORK | cut -d '/' -f1)6
echo "$API_VIP $API_NAME" >> /etc/hosts
echo "$INGRESS_VIP $APPS_NAME" >> /etc/hosts


curl -X PATCH -H "Content-Type: application/json" \
    -d "{\"service_networks\":[{\"cidr\":\"fd02::/112\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"cluster_networks\":[{\"cidr\": \"fd01::/48\",\"cluster_id\":\"${CLUSTER_ID}\",\"host_prefix\": 64}]}" \
    ${API}/clusters/${CLUSTER_ID}

curl -X PATCH -H "Content-Type: application/json" \
    -d "{\"api_vips\":[{\"ip\":\"${API_VIP}\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"ingress_vips\":[{\"ip\":\"${INGRESS_VIP}\",\"cluster_id\":\"${CLUSTER_ID}\"}]}" \
    ${API}/clusters/${CLUSTER_ID}


# VIP and networks for SNO
M_DOMAIN=$(virsh list --all --name | grep extraworker)
MAC=$(virsh dumpxml $VM_DOMAIN | xmllint --xpath "//interface[source/@bridge='$BRIDGE']/mac/@address" - 2>/dev/null | sed 's/ address="\([^"]*\)"/\1/')
IP=$(virsh net-dumpxml $BRIDGE | xmllint --xpath "//host[@id][contains(@id, '$MAC')]/@ip" - | cut -d '"' -f2)
echo "$IP $API_NAME" >> /etc/hosts

curl -X PATCH -H "Content-Type: application/json" \
    -d "{\"service_networks\":[{\"cidr\":\"fd02::/112\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"machine_networks\":[{\"cidr\":\"${HOST_NETWORK}\",\"cluster_id\":\"${CLUSTER_ID}\"}],\"cluster_networks\":[{\"cidr\": \"fd01::/48\",\"cluster_id\":\"${CLUSTER_ID}\",\"host_prefix\": 64}]}" \
    ${API}/clusters/${CLUSTER_ID}
