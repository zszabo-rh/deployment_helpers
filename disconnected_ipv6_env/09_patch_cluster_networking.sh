set -eu
source config.env

if [ "${MASTERS}" -eq 1 ]; then
    echo "[INFO] Single node (SNO) detected, patching VIP and networks..."
    VM_DOMAIN=$(virsh list --all --name | grep extraworker)
    MAC=$(virsh dumpxml $VM_DOMAIN | xmllint --xpath "//interface[source/@bridge='$BRIDGE']/mac/@address" - 2>/dev/null | sed 's/ address="\([^"]*\)"/\1/')
    API_VIP=$(virsh net-dumpxml $BRIDGE | xmllint --xpath "//host[@id][contains(@id, '$MAC')]/@ip" - | cut -d '"' -f2)
    INGRESS_VIP=${API_VIP}
    envsubst < networking_patch_sno.json > networking_patch.json
else
    echo "[INFO] Multi-node (HA) detected, patching VIPs and networks..."
    HOST_NETWORK=$(curl -s ${API}/clusters/${CLUSTER_ID} | jq '.host_networks[0].cidr' | sed 's/^"//' | sed 's/"$//')
    API_VIP=$(echo $HOST_NETWORK | cut -d '/' -f1)5
    INGRESS_VIP=$(echo $HOST_NETWORK | cut -d '/' -f1)6
    envsubst < networking_patch_sno.json > networking_patch.json
fi

curl -s -X PATCH -H "Content-Type: application/json" \
    -d @networking_patch.json \
    ${API}/clusters/${CLUSTER_ID} >/dev/null 2>&1

cat >> /etc/hosts <<EOF
${API_VIP} api.${CLUSTER_NAME}.${BASE_DOMAIN}
${INGRESS_VIP} oauth-openshift.apps.${CLUSTER_NAME}.${BASE_DOMAIN}
${INGRESS_VIP} console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}
${INGRESS_VIP} grafana-openshift-monitoring.apps.${CLUSTER_NAME}.${BASE_DOMAIN}
${INGRESS_VIP} thanos-querier-openshift-monitoring.apps.${CLUSTER_NAME}.${BASE_DOMAIN}
${INGRESS_VIP} prometheus-k8s-openshift-monitoring.apps.${CLUSTER_NAME}.${BASE_DOMAIN}
${INGRESS_VIP} alertmanager-main-openshift-monitoring.apps.${CLUSTER_NAME}.${BASE_DOMAIN}
EOF

echo "[INFO] Cluster networking patch complete."