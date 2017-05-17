#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

if ! [ -d state/ ]; then
  exit "No State, exiting"
  exit 1
fi

source ./state/env.sh
CONCOURSE_DEPLOYMENT_NAME=${CONCOURSE_DEPLOYMENT_NAME:?"!"}
CONCOURSE_USERNAME=${CONCOURSE_USERNAME:?"!"}
CONCOURSE_PASSWORD=${CONCOURSE_PASSWORD:?"!"}
DIRECTOR_FLOATING_IP=172.18.161.254
PRIVATE_CIDR=10.0.0.0/24
PRIVATE_GATEWAY_IP=10.0.0.1
PRIVATE_IP=10.0.0.3
NETWORK_UUID=8e413f91-6ff7-4e97-b534-9287adb5107d
OPENSTACK_IP=172.18.161.6
DNS_IP=10.0.0.2
network_interface=ens7
stemcell_url="http://s3.amazonaws.com/bosh-core-stemcells/openstack/bosh-stemcell-3363.9-openstack-kvm-ubuntu-trusty-go_agent.tgz"
stemcell_sha1=1cddb531c96cc4022920b169a37eda71069c87dd
set -x

mkdir -p bin
PATH=$PATH:$(pwd)/bin

if ! [ -f bin/bosh ]; then
  curl -L "http://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.1-linux-amd64" > bin/bosh
  chmod +x bin/bosh
fi

if ! [ -f state/bosh-creds.yml ]; then
  cat > state/bosh-creds.yml <<EOF
admin_password: admin
api_key: password
auth_url: http://172.18.161.6:5000/v2.0
az: nova
default_key_name: bosh
default_security_groups: [bosh]
director_name: bosh
external_ip: $DIRECTOR_FLOATING_IP
internal_cidr: $PRIVATE_CIDR
internal_gw: $PRIVATE_GATEWAY_IP
internal_ip: $PRIVATE_IP
net_id: $NETWORK_UUID
openstack_domain: nova
openstack_password: password
openstack_project: demo
openstack_tenant: demo
openstack_username: admin
private_key: ../state/bosh.pem
region: RegionOne
EOF
fi

if ! [ -f state/concourse-creds.yml ]; then
  cat > state/concourse-creds.yml <<EOF
concourse_deployment_name: $CONCOURSE_DEPLOYMENT_NAME
concourse_basic_auth_username: $CONCOURSE_USERNAME
concourse_basic_auth_password: $CONCOURSE_PASSWORD
concourse_floating_ip: 172.18.161.253
concourse_external_url: http://ci.foo.com
concourse_basic_auth_username: admin
concourse_basic_auth_password: admin
concourse_atc_db_name: atc
concourse_atc_db_role: concourse
concourse_atc_db_password: concourse
concourse_vm_type: t1.small
concourse_worker_vm_extensions: 50GB_ephemeral_disk
concourse_web_vm_extensions: lb
concourse_db_disk_type: 5GB
EOF
fi


cat > bosh-releases.yml <<EOF
- type: replace
  path: /releases/name=bosh?
  value:
    name: bosh
    version: 261.4
    url: https://bosh.io/d/github.com/cloudfoundry/bosh?v=261.4
    sha1: 4da9cedbcc8fbf11378ef439fb89de08300ad091
EOF

cat > bosh-stemcells.yml <<EOF
- type: replace
  path: /resource_pools/name=vms/stemcell?
  value:
    url: $stemcell_url
    sha1: $stemcell_sha1
EOF

cat > bosh-disk-pools.yml <<EOF
- type: replace
  path: /disk_pools/name=disks?
  value:
    name: disks
    disk_size: 15_000
EOF

if ! [ -f cloud-config.yml ]; then
  cat > cloud-config.yml <<EOF
azs:
- name: z1
  cloud_properties:
    availability_zone: nova

vm_type_defaults: &vm_type_defaults
  az: z1
  cloud_properties:
    instance_type: m1.small

vm_types:
- name: default
  <<: *vm_type_defaults
- name: web
  <<: *vm_type_defaults
- name: database
  <<: *vm_type_defaults
- name: worker
  <<: *vm_type_defaults

disk_types:
- name: default
  disk_size: 2_000
- name: database
  disk_size: 2_000

networks:
- name: private
  type: manual
  subnets:
  - range: $PRIVATE_CIDR
    gateway: $PRIVATE_GATEWAY_IP
    reserved: $DNS_IP
    cloud_properties:
      net_id: $NETWORK_UUID
      security_groups: [bosh]
    az: z1
- name: public
  type: vip
  az: z1

compilation:
  workers: 3
  reuse_compilation_vms: true
  network: private
  <<: *vm_type_defaults
EOF
fi

if ! [ -f state/bosh.pem ]; then
  cat > state/bosh.pem <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA44kTjqdgpX4jdP/ZPpXv4zKh0yNP2pIIIAmdoQ3/WhoTRWlc
HZ1P8qyrQiKG2L+iz1/7sEAcF1IFkOXs5X33u/UVibOzkGBLDfGjkpanAan2qdH9
itLEKVPY2LyblHTsP6c6RwBqOchZVvKAkiZHvw1NyxqiZMPwlTgqtaaIXM1YGIgY
mtFJ+JfQnHk9tm29mcTH8tuo8NFbV+HAtlLVcn1yPcY2qm8xQicEHCHvBAqJtHu0
SxdGoJQkrPoMKEYPxyuzY5xTy1S9ArgeGgQ/geni7SNC8QdYsXLJ0Yv1F3ixSn7P
o8MrFBIHDdR+aWPDf1+OMjUPjpDF2f+z8KR/3QIDAQABAoIBAQCzX6/kSP0+2eb3
6G6KEUew84xxV6gvJepz30C947wHewDwOnQdAJQzOn40P+XQX5rpIsDXHGNI2yd6
KFiOPrUbHsXg7aLEUbU5g+IwwMVd4XCMRfg8BZYRAoGzs1RvP5GzSJD/wkr7zH7p
tXk4PidXbRSD5jZZe8Jg0IuS8nsTtG2Tk6xRZzC6gMbLpIt0sD7EaUTblKXJoJ7s
X2GI5tK/pQ06fWuLtdkXWiXe01HSyjUQ0mUsP8Msf61TLWNpEyElpQlNZJg4R9uN
JbmeiDQQngajGy/Gs7G1ODmDgb/xXd/0DP8ap+zQBgwLswTQOyUfzjl98l/584/r
siO1G0CdAoGBAPGDi0X6OiUoJjWh414NA9Yi9mSCRPbZbuoPtw4V6admVviYwLOf
6DOEDMRmp4r1JihcpByL9UiE2FHNmecJIZo4vq+3tRxvAaoJ+qvK0LW70ANJQg+J
SBm/nQdIrja/befKjGdapT6ZJR7Ysk9W1pH5Z/0B1XBvW/Sl9pGCYzmHAoGBAPEu
5MB8lv6Xx+Zw/5F5xx7LFemaIkGfFcaqnbvEZbF7P09s41oY6igTvRQ0QrzwvaSN
dn6gZG1YxSUbP4xRLiZr0v0Mq3xUc1yZEo9HrPFN8SCcBFjhZlxv72IuWheJy9KF
8VTUPP1Ay0g3hD2iS9cYRsqIRVm9imaLrzG+0ER7AoGBAJdjxtTJotMR1Mm/vd+B
twrvBZZBVmuKJo2P5kZtE/b8Hr5cOkcekJZiSwJ9+r4PJ6kbUUAXt1yK8XJtt/Br
9+VNdrJ9LIkzSE7HTJuNWcDhhuXYcRF+E3UYeJ1NQO9Old07SUGsP3L62pr4aOV0
4LHGLhoZoSqGk5TKx8G0gvBXAoGAI7zOGpObkCgPb98Ij5ba4X44RgAX2V9oS6LW
co88flsD25IH8j7E26FpIAhKZ1LI1ww7JbJAj09bDw+FkBYrX3gUsHhjJK4i1fK8
pEx7nNnuw+U6Y60qjMHtV8AEi35YnF5Kj0ZPrzsdpBrN1pAo6rtnKfWdSRnj2yQR
lq5uj+cCgYBS6dj/noYalrb8izifVX/YcDpHX/ppexnD3dGIRx/ZUDoQzRtcKESO
X5xdkeyISESEgpY9Qf+V7wy/YS4V9schYbXMnRulP5xCuxmhjm1bTw3w6yc3RCzG
4WeUesbrO/5ffHteVU01BGN8DLF3LjfwojBGheV8Y4pM1KtIKdfJyg==
-----END RSA PRIVATE KEY-----
EOF
  chmod 600 state/bosh.pem
fi

cat > bosh-concourse-deployment.yml <<EOF
---
name: bosh-concourse

releases:
- name: concourse
  url: https://bosh.io/d/github.com/concourse/concourse?v=2.7.0
  sha1: 826932f631d0941b3e4cc9cb19e0017c7f989b56
  version: 2.7.0
- name: garden-runc
  url: https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=1.3.0
  sha1: 816044289381e3b7b66dd73fbcb20005594026a3
  version: 1.3.0

stemcells:
- alias: trusty
  os: ubuntu-trusty
  version: latest

instance_groups:
- name: web
  instances: 1
  vm_type: web
  stemcell: trusty
  azs: [z1]
  networks:
  - name: private
    default: [dns, gateway]
  - name: public
    static_ips: [((concourse_floating_ip))]
  jobs:
  - name: atc
    release: concourse
    properties:
      external_url: ((concourse_external_url))
      basic_auth_username: ((concourse_basic_auth_username))
      basic_auth_password: ((concourse_basic_auth_password))
      postgresql_database: ((concourse_atc_db_name))
  - name: tsa
    release: concourse
    properties: {}

- name: db
  instances: 1
  # replace with a VM type from your BOSH Director's cloud config
  vm_type: database
  stemcell: trusty
  # replace with a disk type from your BOSH Director's cloud config
  persistent_disk_type: default
  azs: [z1]
  networks: [{name: private}]
  jobs:
  - name: postgresql
    release: concourse
    properties:
      databases:
      - name: ((concourse_atc_db_name))
        role: ((concourse_atc_db_role))
        password: ((concourse_atc_db_password))

- name: worker
  instances: 1
  # replace with a VM type from your BOSH Director's cloud config
  vm_type: worker
  stemcell: trusty
  azs: [z1]
  networks: [{name: private}]

  jobs:
  - name: groundcrew
    release: concourse
    properties: {}

  - name: baggageclaim
    release: concourse
    properties: {}

  - name: garden
    release: garden-runc
    properties:
      garden:
        listen_network: tcp
        listen_address: 0.0.0.0:7777

update:
  canaries: 1
  max_in_flight: 1
  serial: false
  canary_watch_time: 1000-60000
  update_watch_time: 1000-60000
EOF

if ! dpkg -l build-essential; then
  DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qqy \
    build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev sqlite3
fi

if ! route -n | grep $DIRECTOR_FLOATING_IP; then
  sudo route add $DIRECTOR_FLOATING_IP gw $OPENSTACK_IP || true
fi

if ! route -n | grep $PRIVATE_CIDR; then
  sudo route add -net $PRIVATE_CIDR gw $OPENSTACK_IP || true
fi

if ! [ -d bosh-deployment ]; then
  git clone https://github.com/cloudfoundry/bosh-deployment.git
fi

bosh create-env bosh-deployment/bosh.yml \
  --state bosh-deployment-state.json \
  -o bosh-deployment/openstack/cpi.yml \
  -o bosh-deployment/openstack/keystone-v2.yml \
  -o bosh-deployment/external-ip-not-recommended.yml \
  -o bosh-releases.yml \
  -o bosh-stemcells.yml \
  -o bosh-disk-pools.yml \
  --vars-store state/bosh-creds.yml \
  --tty \
  ;

bosh interpolate ./bosh-creds.yml --path /director_ssl/ca > director.pem
bosh alias-env --ca-cert director.pem -e $DIRECTOR_FLOATING_IP bosh
bosh log-in -e bosh --client admin --client-secret admin
bosh update-cloud-config -e bosh --non-interactive cloud-config.yml
bosh upload-stemcell -e bosh $stemcell_url
bosh deploy -e bosh -d bosh-concourse bosh-concourse-deployment.yml \
  -o concourse-groundcrew-properties.yml \
  --vars-store state/concourse-creds.yml \
  -n \
  ;
