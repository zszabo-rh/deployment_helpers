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
export CLUSTER_NAME=${CLUSTER_NAME}
export BASE_DOMAIN=redhat.com
export IP_STACK=v6
export BMC_DRIVER=redfish-virtualmedia
export PROVISIONING_NETWORK_PROFILE=Disabled
export REDFISH_EMULATOR_IGNORE_BOOT_DEVICE=True

export NUM_MASTERS=0
export NUM_WORKERS=0
export NUM_EXTRA_WORKERS=${VMS}
export EXTRA_WORKER_VCPU=8
export EXTRA_WORKER_MEMORY=36000
export VM_EXTRADISKS=true
export VM_EXTRADISKS_LIST="vda vdb"
export VM_EXTRADISKS_SIZE=200G
EOF

cp ../pull_secret.json . >/dev/null 2>&1

echo "[INFO] Running make requirements and configure..."
make requirements configure >/dev/null 2>&1

cd ..
echo "[INFO] VM setup complete."