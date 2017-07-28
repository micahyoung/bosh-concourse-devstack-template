#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source state/env.sh
true ${ESX_USERNAME:?"!"}
true ${ESX_PASSWORD:?"!"}
true ${ESX_HOST:?"!"}
true ${ESX_THUMBPRINT:?"!"}

if ! [ -f bin/govc ]; then
  curl -L https://github.com/vmware/govmomi/releases/download/v0.15.0/govc_darwin_amd64.gz > bin/govc.gz
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
export GOVC_DATASTORE=datastore1
export GOVC_NETWORK="VM Network"
#export GOVC_RESOURCE_POOL='*/Resources'

#bin/govc datastore.mkdir VM-new
bin/govc vm.power reboot
#bin/govc datastore.cp VM/VM-flat.vmdk VM-new/VM-flat.vmdk
#bin/govc datastore.ls VM-new/
#bin/govc import.ova -name VM '[usb-datastore1]/image.ova'
#bin/govc vm.clone -folder VMclone -vm VM VMclone
#bin/govc import.ova -name VM bin/image.ova
#bin/govc vm.change -vm VM -nested-hv-enabled=true
#bin/govc vm.disk.change -vm VM -size 300G



#docker run -it -v `pwd`/bin:/tmp/bin ovftool-image \
#  ovftool \
#          --name=test \
#          --datastore=datastore1 \
#          --memorySize:id-ovf=130000 \
#          --numberOfCpus:id-ovf=12 \
#          --targetSSLThumbprint=$ESX_THUMBPRINT \
#          --powerOn \
#          --overwrite \
#          /tmp/bin/image.ova \
#          vi://$ESX_USERNAME:$ESX_PASSWORD@$ESX_HOST/ 

#  bash -c "
#  cot edit-hardware \
#    /tmp/bin/image.ova \
#    -o /tmp/vm.ova \
#    -c 6 \
#    -m 130GB \
#    --nic-types VMXNET3 \
#  ;
#  ovftool \
#    --name=test \
#    --datastore=datastore1 \
#    --diskMode=thin \
#    --powerOn \
#    --overwrite \
#    --targetSSLThumbprint=$ESX_THUMBPRINT \
#    /tmp/vm.ova \
#    vi://$ESX_USERNAME:$ESX_PASSWORD@$ESX_HOST/ \
#  ;
#  "
