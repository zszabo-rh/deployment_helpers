set -eu
source config.env

git clone https://github.com/openshift-metal3/dev-scripts && cd dev-scripts 

cat >> config_root.sh<< EOF
#!/bin/bash
set +x
export CI_TOKEN=${CI_TOKEN} 
set -x

export WORKING_DIR=/home/dev-scripts
export CLUSTER_NAME=dev
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

cp ../pull_secret.json .

make requirements configure
cd ..
