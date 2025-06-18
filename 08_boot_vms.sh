set -eu
source config.env

echo "[INFO] Fixing DNS for VMs..."
rm -rf /tmp/*.xml* >/dev/null 2>&1
virsh net-dumpxml $BRIDGE > /tmp/$BRIDGE.xml
sed -i "s|  </dns>|    <host ip='${REGISTRY_HOST_IP6}'>\n      <hostname>${REGISTRY_HOSTNAME}</hostname>\n    </host>\n  </dns>|" /tmp/$BRIDGE.xml

virsh net-destroy ${BRIDGE} >/dev/null 2>&1
virsh net-define /tmp/${BRIDGE}.xml >/dev/null 2>&1
virsh net-start ${BRIDGE} >/dev/null 2>&1

echo "[INFO] Attaching discovery ISO and setting boot order for VMs..."
for VM_DOMAIN in $(virsh list --all --name); do
  virsh dumpxml ${VM_DOMAIN} > /tmp/${VM_DOMAIN}.xml && cp /tmp/${VM_DOMAIN}.xml /tmp/${VM_DOMAIN}.xml.bak
  # Remove current "first boot device" if exists
  sed -i "s|      <boot order='1'/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|      <boot order='2'/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|      <boot order='3'/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|      <boot order='4'/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|      <source file=''/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|      <source file='.*iso'/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|    <boot dev='network'/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|    <boot dev='cdrom'/>$||" /tmp/${VM_DOMAIN}.xml
  sed -i "s|    <boot dev='hd'/>$||" /tmp/${VM_DOMAIN}.xml
  # Attach ISO to existing cdrom and mark it as last boot device
  sed -i "s|<target dev='sda' bus='scsi'/>|<target dev='sda' bus='scsi'/>\n      <boot order='1'/>|" /tmp/${VM_DOMAIN}.xml
  sed -i "s|<target dev='vda' bus='virtio'/>|<target dev='vda' bus='virtio'/>\n      <boot order='2'/>|" /tmp/${VM_DOMAIN}.xml
  sed -i "s|<target dev='vdb' bus='virtio'/>|<target dev='vdb' bus='virtio'/>\n      <boot order='3'/>|" /tmp/${VM_DOMAIN}.xml
  sed -i "s|<target dev='sdb' bus='sata'/>|<target dev='sdb' bus='sata'/>\n      <boot order='4'/>\n      <source file='${ISO_PATH}'/>|" /tmp/${VM_DOMAIN}.xml
  virsh define /tmp/${VM_DOMAIN}.xml >/dev/null 2>&1
  virsh start ${VM_DOMAIN} >/dev/null 2>&1
done

echo "[INFO] Waiting for ${VMS} hosts to register..."
while [ "$(curl --silent ${API}/events\?cluster_id\=${CLUSTER_ID} | jq | grep host_registration_succeeded | wc -l)" -ne "${VMS}" ]; do
  sleep 5
done
echo "[INFO] All ${VMS} hosts are registered."