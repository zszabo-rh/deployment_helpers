# disconnected_ipv6_env

```bash
git clone https://github.com/zszabo-rh/deployment_helpers.git
cd deployment_helpers/disconnected_ipv6_env

export CI_TOKEN=<your_ci_token># https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/
export QUAY_USER=<your_quay_username> # https://access.redhat.com/ or https://quay.io
export QUAY_PASS=<your_quay_password>
export OFFLINE_ACCESS_TOKEN="<your_offline_ci_token>"

./00_preparation.sh
./01_setup_vms.sh
./02_fix_certificate.sh
./03_firewall.sh
./04_registry.sh
./05_assisted_installer.sh
./06_disable_ipv4.sh
./07_setup_cluster.sh
./08_boot_vms.sh
```
Wait for discovery to finish
Dashboard (http://${hostname}:8080/assisted-installer/clusters)
```bash
./09_patch_cluster_networking.sh
./10_start_cluster_install.sh
```
