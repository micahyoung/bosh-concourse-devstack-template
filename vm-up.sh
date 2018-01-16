#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source state/env.sh
true ${ESX_USERNAME:?"!"}
true ${ESX_PASSWORD:?"!"}
true ${ESX_HOST:?"!"}
true ${ESX_THUMBPRINT:?"!"}
true ${ESX_DATASTORE:?"!"}
true ${ESX_NETWORK:?"!"}
true ${VM_NAME:?"!"}
true ${VM_PASSWORD:?"!"}
true ${VM_AUTHORIZED_KEY:?"!"}
true ${VM_IP:?"!"}
true ${VM_NETMASK:?"!"}

mkdir -p bin
if ! [ -f bin/govc ]; then
  curl -L https://github.com/vmware/govmomi/releases/download/v0.15.0/govc_linux_amd64.gz > bin/govc.gz
  gzip -d bin/govc.gz
  chmod +x bin/govc
fi


if ! [ -f bin/image.ova ]; then
  curl -L https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64.ova > bin/image.ova
fi

export GOVC_INSECURE=1
export GOVC_URL=$ESX_HOST
export GOVC_USERNAME=$ESX_USERNAME
export GOVC_PASSWORD=$ESX_PASSWORD
export GOVC_DATASTORE=$ESX_DATASTORE
export GOVC_NETWORK=$ESX_NETWORK
export GOVC_VM=$VM_NAME
#export GOVC_RESOURCE_POOL='*/Resources'

cat > meta-data <<EOF
local-hostname: localhost
network-interfaces: |
  auto lo
  iface lo inet loopback

  auto ens32
  iface ens32 inet dhcp

  auto ens192
  iface ens192 inet static
    address $VM_IP
    netmask $VM_NETMASK
EOF

cat > user-data <<EOF
#cloud-config
password: $VM_PASSWORD
chpasswd: { expire: False }
ssh_pwauth: True
ssh_authorized_keys:
  - $VM_AUTHORIZED_KEY
EOF

xorrisofs -volid cidata -joliet -rock user-data meta-data > bin/cloud-init.iso
qemu-img convert -O vmdk bin/cloud-init.iso bin/cloud-init.vmdk

bin/govc import.ova -name $VM_NAME bin/image.ova
bin/govc import.vmdk -force=true bin/cloud-init.vmdk /$VM_NAME/
bin/govc vm.change -vm $VM_NAME -c 6 -m 130000 -nested-hv-enabled=true -sync-time-with-host=true

bin/govc vm.disk.attach -disk /$VM_NAME/cloud-init.vmdk -link=false
bin/govc vm.disk.change -vm $VM_NAME -disk.key 2000 -size 300G
bin/govc device.remove floppy-8000 

bin/govc vm.network.add -vm $VM_NAME -net "VM Network"

bin/govc snapshot.create -vm $VM_NAME initial-snapshot
