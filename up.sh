#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

if ! [ -d state/ ]; then
  exit "No State, exiting"
  exit 1
fi

source ./state/env.sh
true ${CONCOURSE_DEPLOYMENT_NAME:?"!"}
true ${CONCOURSE_USERNAME:?"!"}
true ${CONCOURSE_PASSWORD:?"!"}
true ${SYSTEM_DOMAIN:?"!"}
true ${OPENSTACK_IP:?"!"}
true ${HTTP_PROXY:?"!"}
true ${PRIVATE_NETWORK_UUID:?"!"}
DIRECTOR_FLOATING_IP=172.18.161.254
CONCOURSE_FLOATING_IP=172.18.161.253
PRIVATE_CIDR=10.0.0.0/24
PRIVATE_GATEWAY_IP=10.0.0.1
PRIVATE_IP=10.0.0.3

set -x

mkdir -p bin
PATH=$PATH:$(pwd)/bin

if ! [ -f bin/bosh ]; then
  curl -L "http://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.1-linux-amd64" > bin/bosh
  chmod +x bin/bosh
fi

cat > state/concourse-creds.yml <<EOF
concourse_deployment_name: $CONCOURSE_DEPLOYMENT_NAME
concourse_basic_auth_username: $CONCOURSE_USERNAME
concourse_basic_auth_password: $CONCOURSE_PASSWORD
concourse_floating_ip: $CONCOURSE_FLOATING_IP
concourse_external_url: http://ci.foo.com
concourse_atc_db_name: atc
concourse_atc_db_role: concourse
concourse_atc_db_password: concourse
concourse_vm_type: t1.small
concourse_worker_vm_extensions: 50GB_ephemeral_disk
concourse_web_vm_extensions: lb
concourse_db_disk_type: 5GB
EOF

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
    url: http://s3.amazonaws.com/bosh-core-stemcells/openstack/bosh-stemcell-3363.9-openstack-kvm-ubuntu-trusty-go_agent.tgz
    sha1: 1cddb531c96cc4022920b169a37eda71069c87dd
EOF

cat > bosh-disk-pools.yml <<EOF
- type: replace
  path: /disk_pools/name=disks?
  value:
    name: disks
    disk_size: 15_000
EOF

cat > state/cloud-config.yml <<EOF
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
- name: t2.small
  az: z1
  cloud_properties:
    instance_type: m1.small
- name: m3.medium
  az: z1
  cloud_properties:
    instance_type: m1.medium
- name: m3.large
  az: z1
  cloud_properties:
    instance_type: m1.large
- name: c3.large
  az: z1
  cloud_properties:
    instance_type: m1.large
- name: r3.xlarge
  az: z1
  cloud_properties:
    instance_type: r3.xlarge

vm_extensions:
- name: 5GB_ephemeral_disk
  cloud_properties:
    ephemeral_disk:
      size: 5_000
- name: 10GB_ephemeral_disk
  cloud_properties:
    ephemeral_disk:
      size: 10_000
- name: 50GB_ephemeral_disk
  cloud_properties:
    ephemeral_disk:
      size: 10_000
- name: 100GB_ephemeral_disk
  cloud_properties:
    ephemeral_disk:
      size: 100_000
- name: 500GB_ephemeral_disk
  cloud_properties:
    ephemeral_disk:
      size: 10_000
- name: 1TB_ephemeral_disk
  cloud_properties:
    ephemeral_disk:
      size: 10_000
- name: ssh-proxy-and-router-lb
  cloud_properties:
    ports:
    - host: 80
    - host: 443
    - host: 2222
- name: cf-tcp-router-network-properties
  cloud_properties:
    ports:
    - host: 1024-1123
- name: cf-router-network-properties
- name: diego-ssh-proxy-network-properties

disk_types:
- name: default
  disk_size: 2_000
- name: database
  disk_size: 2_000
- name: 5GB
  disk_size: 5_000
- name: 10GB
  disk_size: 10_000
- name: 100GB
  disk_size: 10_000

networks:
- name: default
  type: manual
  subnets:
  - range: $PRIVATE_CIDR
    gateway: $PRIVATE_GATEWAY_IP
    reserved: $PRIVATE_GATEWAY_IP-$PRIVATE_IP
    cloud_properties:
      net_id: $PRIVATE_NETWORK_UUID
      security_groups: [bosh,cf]
    az: z1
- name: private
  type: manual
  subnets:
  - range: $PRIVATE_CIDR
    gateway: $PRIVATE_GATEWAY_IP
    reserved: $PRIVATE_GATEWAY_IP-$PRIVATE_IP
    cloud_properties:
      net_id: $PRIVATE_NETWORK_UUID
      security_groups: [bosh]
    az: z1
- name: public
  type: vip
  az: z1

compilation:
  workers: 4
  reuse_compilation_vms: true
  network: private
  az: z1
  cloud_properties:
    instance_type: m1.xlarge
EOF

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

cat > bosh-concourse-deployment.yml <<EOF
---
name: bosh-concourse

releases:
- name: concourse
  version: 2.7.0
- name: garden-runc
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

if ! dpkg -l build-essential ruby polipo; then
  sudo mkdir /etc/polipo
  sudo tee /etc/polipo/config 2>/dev/null <<EOF
logSyslog = true
logFile = /var/log/polipo/polipo.log
proxyAddress = "0.0.0.0"    # IPv4 only
allowedClients = 127.0.0.1, 172.18.161.0/24, $OPENSTACK_IP, $PRIVATE_CIDR
EOF

  DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qqy \
    build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev sqlite3 polipo
fi

if ! [ -d bosh-deployment ]; then
  git clone https://github.com/cloudfoundry/bosh-deployment.git
fi

if ! [ -d cf-deployment ]; then
  git clone https://github.com/cloudfoundry/cf-deployment.git
fi

bosh create-env bosh-deployment/bosh.yml \
  --state state/bosh-deployment-state.json \
  -o bosh-deployment/openstack/cpi.yml \
  -o bosh-deployment/openstack/keystone-v2.yml \
  -o bosh-deployment/external-ip-not-recommended.yml \
  -o bosh-deployment/misc/proxy.yml \
  -o bosh-releases.yml \
  -o bosh-stemcells.yml \
  -o bosh-disk-pools.yml \
  -v admin_password=admin \
  -v api_key=password \
  -v auth_url=http://$OPENSTACK_IP:5000/v2.0 \
  -v az=nova \
  -v default_key_name=bosh \
  -v default_security_groups=[bosh] \
  -v director_name=bosh \
  -v external_ip=$DIRECTOR_FLOATING_IP \
  -v internal_cidr=$PRIVATE_CIDR \
  -v internal_gw=$PRIVATE_GATEWAY_IP \
  -v internal_ip=$PRIVATE_IP \
  -v net_id=$PRIVATE_NETWORK_UUID \
  -v openstack_domain=nova \
  -v openstack_password=password \
  -v openstack_project=demo \
  -v openstack_tenant=demo \
  -v openstack_username=admin \
  -v private_key=../state/bosh.pem \ 
  -v region=RegionOne \
  -v http_proxy=$HTTP_PROXY \
  -v https_proxy=$HTTP_PROXY \
  -v no_proxy="localhost,127.0.0.1,$OPENSTACK_IP,$PRIVATE_IP,$PRIVATE_CIDR,$DIRECTOR_FLOATING_IP,$PRIVATE_GATEWAY_IP,$DNS_IP,$CONCOURSE_FLOATING_IP" \
  --vars-store state/bosh-creds.yml \
  --tty \
;

bosh alias-env --ca-cert <(bosh interpolate state/bosh-creds.yml --path /director_ssl/ca) -e $DIRECTOR_FLOATING_IP bosh
bosh log-in -e bosh --client admin --client-secret admin

bosh update-cloud-config -e bosh --non-interactive state/cloud-config.yml

# CF
bosh deploy -e bosh  -d cf cf-deployment/cf-deployment.yml \
  -o cf-deployment/operations/scale-to-one-az.yml \
  -o cf-deployment/operations/use-latest-stemcell.yml \
  -o cf-deployment/operations/test/alter-ssh-proxy-redirect-uri.yml \
  -v system_domain=$SYSTEM_DOMAIN \
  --vars-store state/cf-creds.yml \
  -n \
;

# Concourse
bosh deploy -e bosh -d bosh-concourse bosh-concourse-deployment.yml \
  --vars-store state/concourse-creds.yml \
  -n \
;
