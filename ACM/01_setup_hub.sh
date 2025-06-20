set -eu
source config.env

echo "[INFO] Cloning dev-scripts repository..."
git clone -q https://github.com/openshift-metal3/dev-scripts >/dev/null 2>&1
cd dev-scripts

cat >> config_root.sh<< EOF
#!/bin/bash
set +x
export CI_TOKEN=${CI_TOKEN} 
set -x

export WORKING_DIR=/home/dev-scripts
export OPENSHIFT_RELEASE_STREAM=${OCP_RELEASE_STREAM}
export CLUSTER_NAME=${CLUSTER_NAME}
export BASE_DOMAIN=${BASE_DOMAIN}
export IP_STACK=v4
export BMC_DRIVER=redfish-virtualmedia
export PROVISIONING_NETWORK_PROFILE=Disabled
export REDFISH_EMULATOR_IGNORE_BOOT_DEVICE=True

export NUM_MASTERS=3
export MASTER_VCPU=10
export MASTER_MEMORY=36000
export MASTER_DISK=150

export NUM_WORKERS=1
export WORKER_DISK=150

export NUM_EXTRA_WORKERS=${VMS}
export EXTRA_WORKER_VCPU=12
export EXTRA_WORKER_MEMORY=24576
export VM_EXTRADISKS=true
export VM_EXTRADISKS_LIST="vda vdb"
export VM_EXTRADISKS_SIZE=200G
EOF

cp ../pull_secret.json . >/dev/null 2>&1

echo "[INFO] Setting up environment..."
make >/dev/null 2>&1
make assisted_deployment_requirements >/dev/null 2>&1
export KUBECONFIG=/home/test/dev-scripts/ocp/dev/auth/kubeconfig
oc patch schedulers.config.openshift.io cluster --type='json' -p='[{"op": "replace", "path": "/spec/mastersSchedulable", "value": true}]' >/dev/null 2>&1
oc patch storageclass assisted-service -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null 2>&1
oc patch provisioning provisioning-configuration --type='json' -p='[{"op": "add", "path": "/spec/watchAllNamespaces", "value": true}]' >/dev/null 2>&1
echo "[INFO] KUBECONFIG is at ${KUBECONFIG}"
echo "[INFO] kubeadmin password is $(cat /home/test/dev-scripts/ocp/dev/auth/kubeadmin-password)"

cd ..