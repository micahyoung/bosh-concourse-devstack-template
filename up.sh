#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

if ! [ -d state ]; then
  exit "No State, exiting"
  exit 1
fi

if ! [ -d opsfiles ]; then
  mkdir opsfiles
fi

source ./state/env.sh
true ${CONCOURSE_DEPLOYMENT_NAME:?"!"}
true ${CONCOURSE_USERNAME:?"!"}
true ${CONCOURSE_PASSWORD:?"!"}
true ${SYSTEM_DOMAIN:?"!"}
true ${OPENSTACK_HOST:?"!"}
true ${PRIVATE_NETWORK_UUID:?"!"}
CONCOURSE_FLOATING_IP=172.18.161.253
PRIVATE_CIDR=10.0.0.0/24
PRIVATE_GATEWAY_IP=10.0.0.1
PRIVATE_IP=10.0.0.3
OPENSTACK_USERNAME=admin
OPENSTACK_PASSWORD=password
OPENSTACK_PROJECT=demo

export OS_PROJECT_NAME=$OPENSTACK_PROJECT
export OS_USERNAME=$OPENSTACK_USERNAME
export OS_PASSWORD=$OPENSTACK_PASSWORD
export OS_AUTH_URL=http://$OPENSTACK_HOST/v2.0
set -x

mkdir -p bin
PATH=$PATH:$(pwd)/bin

if ! [ -f bin/bosh ]; then
  curl -L "http://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.1-linux-amd64" > bin/bosh
  chmod +x bin/bosh
fi

if ! [ -f state/concourse-manifest.yml ]; then
  curl -L 'https://raw.githubusercontent.com/concourse/concourse/c8a9ab4d5fb3be4f0343f3552b1da241a59dae92/manifests/single-vm.yml' > state/concourse-manifest.yml
fi

cat > opsfiles/concourse-init-opsfile.yml <<EOF
- type: replace
  path: /cloud_provider?
  value: 
    mbus: https://mbus:p2an3m7idfm6vmqp3w74@((web_ip)):6868
    template:
      name: openstack_cpi
      release: bosh-openstack-cpi
    ssh_tunnel: 
      host: ((web_ip)) # <--- Replace with your Elastic IP address
      port: 22
      user: vcap
      private_key: ./bosh.pem # Path relative to this manifest file
    properties:
      agent:
        mbus: https://mbus:p2an3m7idfm6vmqp3w74@0.0.0.0:6868
      blobstore:
        path: /var/vcap/micro_bosh/data/cache
        provider: local
      openstack:
        auth_url: ((auth_url))
        username: ((openstack_username))
        api_key: ((openstack_password))
        domain: ((openstack_domain))
        tenant: ((openstack_tenant))
        project: ((openstack_project))
        region: ((region))
        default_key_name: ((default_key_name))
        default_security_groups: ((default_security_groups))
        human_readable_vm_names: true
      ntp:
      - time1.google.com
      - time2.google.com
      - time3.google.com
      - time4.google.com
- type: replace
  path: /releases
  value:
  - name: concourse
    sha1: 99e134676df72e18c719ccfbd7977bd9449e6fd4
    url: https://bosh.io/d/github.com/concourse/concourse?v=3.8.0
  - name: garden-runc
    url: https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=1.9.0
    sha1: 77bfe8bdb2c3daec5b40f5116a6216badabd196c
  - name: postgres
    url: https://bosh.io/d/github.com/cloudfoundry/postgres-release?v=23
    sha1: 4b5265bfd5f92cf14335a75658658a0db0bca927
  - name: bosh-openstack-cpi
    url: https://bosh.io/d/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?v=35
    sha1: 314b040cb0df72651174d262892aa8c4d75f9031
- type: replace
  path: /resource_pools?
  value: 
    - name: vms
      network: default
      stemcell:
        sha1: 4f3501a3c374e7e107ee1219ff08d55aa5001331
        url: https://bosh.io/d/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent?v=3468.19
      cloud_properties:
        instance_type: concourse
      env:
        bosh:
          password: '*'
- type: replace
  path: /networks?
  value:
  - name: default
    subnets:
    - dns:
      - 8.8.8.8
      gateway: 10.0.0.1
      range: 10.0.0.0/24
      static_ips: ((web_ip))
      cloud_properties:
        net_id: ((net_id))
        security_groups: ((default_security_groups))
    type: manual
- type: replace
  path: /instance_groups/name=concourse/resource_pool?
  value: vms 
- type: replace
  path: /instance_groups/name=concourse/networks?
  value: 
    - default:
      - dns
      - gateway
      name: default
      static_ips:
      - ((web_ip))
- type: replace
  path: /instance_groups/name=concourse/jobs/name=tsa/properties/bind_port?
  value: 2222
- type: replace
  path: /instance_groups/name=concourse/jobs/name=groundcrew/properties/baggageclaim?
  value:
    url: http://127.0.0.1:7788
- type: replace
  path: /instance_groups/name=concourse/jobs/name=groundcrew/properties/tsa/host?
  value: 127.0.0.1
- type: replace
  path: /instance_groups/name=concourse/jobs/name=groundcrew/properties/tsa/host_public_key?
  value: ((tsa_host_key.public_key))
- type: replace
  path: /instance_groups/name=concourse/jobs/name=groundcrew/properties/tsa/port?
  value: 2222
- type: replace
  path: /instance_groups/name=concourse/jobs/name=atc/properties/postgresql/host?
  value: 127.0.0.1 
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

if ! dpkg -l build-essential ruby; then
  DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qqy \
    build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt-dev libxml2-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev libsqlite3-dev sqlite3
fi

if ! grep -q concourse <(openstack flavor list -c Name -f value); then
  openstack flavor create \
    concourse \
    --public \
    --vcpus 2 \
    --ram 8192 \
    --disk 30 \
  ;
fi

bosh create-env state/concourse-manifest.yml \
  --state state/concourse-state.json \
  -o opsfiles/concourse-init-opsfile.yml \
  -v admin_password=admin \
  -v api_key=password \
  -v auth_url=http://$OPENSTACK_HOST/v2.0 \
  -v az=nova \
  -v default_key_name=bosh \
  -v default_security_groups=[bosh] \
  -v director_name=bosh \
  -v internal_cidr=$PRIVATE_CIDR \
  -v internal_gw=$PRIVATE_GATEWAY_IP \
  -v internal_ip=$PRIVATE_IP \
  -v net_id=$PRIVATE_NETWORK_UUID \
  -v openstack_password=$OPENSTACK_PASSWORD \
  -v openstack_project=$OPENSTACK_PROJECT \
  -v openstack_tenant=$OPENSTACK_PROJECT \
  -v openstack_username=$OPENSTACK_USERNAME \
  -v openstack_domain=demo \
  -v private_key=bosh.pem \
  -v region=RegionOne \
  -v vm_type=m1.medium \
  -v concourse_version=3.8.0 \
  -v deployment_name=$CONCOURSE_DEPLOYMENT_NAME \
  -v garden_runc_version=1.9.0 \
  -v network_name=private \
  -v postgres_password=password \
  -v token_signing_key='{
       private_key: "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA0sx3a3Lhz6/u6mA5DoHen/XnctAPxBtsFlI3je/cdLjM60G9\nL0Fyj2dEyrz/7QWRFL8Rvk2gyOPDUB1QbmZ/0FFXPhNOfaLraqDSi60CqG4ZKbmo\neI9OTGgJZGLSKYfs/P1oZGQaPaUBtqqE9DgQu3TNshCkp5gzbu5vk5ZSE1cLTlq7\ni7smx80W9hRhuLjeis7QJpJksNvvaAKawxXELLAe8F23h19pje4++mDftwM9FzIq\n98WQ0rNTvjuxjjys39KDYiV8bADNftRbHSCqS723dfdNOdfj26WmkmhfxkIg8aAF\nV+bzSwSZ8ZkwA/9Wu4RaJTKHzokFZ4fFTdW+2QIDAQABAoIBAQCn2iopRAQtFWF/\n/XjRZXY5F1zh3mz/cfqCV5tnCR0ZUGHT3rffHhUzvT5Y1WBQgwNAatidGUEzVbGb\nZIw8LKAP6AU5J7RzdDxS3pZopC4eofSldfGBdlMZoioAZnQEn/iEhuAOOGtwtKiF\npIhT0yT3r41vAbOqxBYIehIcijD2tgF2qvj1Jhpoqr1whShppbZeWG6//VKSEXAe\na8t5rhsAA+nBOmMV7+rWvVaO65BTtUdt7uLhNWfFKigMyKv6oz93k6IjK8NmlQWM\nM2KfdJQL32S8xMmrcWSAlxmrl0QvxhwpIfLG3dOVEFbLFRkKZMVUqFpmFj6fSa3I\ngpSal6wBAoGBANtAHL0QGOcLeupqWbJGu70a6V5msuPQqQpH0grRFcDSbfvbIMfn\nb0s/J4Tf7QVj1bIi/O5cky8b8TBzUT0TkoNZqJ+ysSWflaUqMqemf7L8cRzMIZ2s\npvYpbrHuMXo+AQETTvTSDVF535Yk9e7lM1lnE4emmZ3Tu1yGaYLkI0SBAoGBAPYh\nshts76017kF3jy18hoR3djLzVm1/JBgFtGRCJnNCUwDy7WoRSs4LKAJJz5O1BcMt\nHxf6+ku5XlY33R9ngJEgdvLGqdeGeh56oEO5T1gEW9fKppgx2Rz6BS6QTYW+rQnq\nIP1oEy7EEkzzMQk/a4+iEaDaM6iOQVB4ItS2Y+5ZAoGACKvgdxnL4ldx5ROPuJ1T\nj4cg87rcGGaISP/OLt9WHOo1r2BbS4y7uh4lUfwJQ81PBlyb5FGFALf6MhBdhizf\n/pHtOWO33eUR5hZlKnxLUKjrUFhCfBn4AIRi/GaPTmZlY8V/ue8U18QaM7YChBBM\nl5ycCSFtsfBN2Lr4MVUUkAECgYEAu6gfMnfRGR/IQtPULxsFOJQYY2pSF/Pa4hHf\nYp1o0XHc9RlCWB9NCGFLJMt/3x8igJezYEYzdW6kdVnsVphEVuIIrrs3HSLjkr9t\n15S+4N2Z5KIWeG1xGn2pW8IbyQAC0E9Yzbv+/CXzygWU+ncHHCC2DgyvXDDxrVeb\nPtC8yikCgYBpVns2/oFLkfm96zRjGBN/XT5GYaQRmBkgu8bDzDfMMzm8RL8odNuF\nlrCG7+1RJYFz1cTojq3NjiRVX5ePpUzpbKQXSFuwa8BHGcwZW0A8zB6vbu5cazcq\nF0jS9ggZibTgY5w+Zykf4pKXV2PsYeCv7I60ODkB5nn5H26C/KB+mQ==\n-----END RSA PRIVATE KEY-----\n",
       public_key: "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0sx3a3Lhz6/u6mA5DoHe\nn/XnctAPxBtsFlI3je/cdLjM60G9L0Fyj2dEyrz/7QWRFL8Rvk2gyOPDUB1QbmZ/\n0FFXPhNOfaLraqDSi60CqG4ZKbmoeI9OTGgJZGLSKYfs/P1oZGQaPaUBtqqE9DgQ\nu3TNshCkp5gzbu5vk5ZSE1cLTlq7i7smx80W9hRhuLjeis7QJpJksNvvaAKawxXE\nLLAe8F23h19pje4++mDftwM9FzIq98WQ0rNTvjuxjjys39KDYiV8bADNftRbHSCq\nS723dfdNOdfj26WmkmhfxkIg8aAFV+bzSwSZ8ZkwA/9Wu4RaJTKHzokFZ4fFTdW+\n2QIDAQAB\n-----END PUBLIC KEY-----\n"
       }' \
  -v tsa_host_key='{
       private_key: "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAsVykdMOrVGmiX30ZyXmp4uqgmqiba7ChGw7vCejDcKbKIZMC\n+13spQxcXMJUV+MDnDl5DTELLBglIiLv7PWpANzaqadFng0NHeBtEbLwO5qypu6J\nNQ4TBL9NsEZGe524EkgE1e9DXZXpuc55JuoFuIyUdw39yr5ATLI+5JE0YWEBP4YN\n027WVGmMOjnWDPCxzp89g9yZgxl9naGqfjcyXvPNRTlH6fHACErXj7/IG+dcgn8g\nR9ISMX1ZdCPY1G2DcLqmr886r3MsJ/wm9Usw8Ph/YivIfA5OGyn7mvGoYdmg++/5\nrSv55brzfhoF0MWX7vr3KPvy0l23K1sGs/KQ1wIDAQABAoIBAHiUz4pC7Vx6ZNYe\nq0V63bFUatQ7BU91ylInGQTXpugTvSCOXlyfQqADg1fdFpKZ2H6B5Ha/fSUBVV2b\n+xpS+g+IF3F4M7B8lwpU5lI+IW2kgwlS6x2S8AMuPJc3b/vjAp4LMJ5yCI67uSeF\n5IA8Yp9RlC5M6NrJ9dUu6etjfQUmWC8E/0wPgSLM/+jDfkWPOkqUjN6LOC5kDJif\nIEVTAlmC1+tx6suvnHb5nFtiDtq1m1aOB+IZ6D5M16DmI/gvldOVb3i5ir94RH8g\nErlrm/2w0SDnnQWjUkDIZIeph/2UnlyAjvd8/B/BDeH/wTOgl+yhfoBl+2yY417p\nkDbOlcECgYEA32Q/+aAwuXplU9MFHTJxa2sXMxih0phHWS/L587zIIFtghoKzVT2\n4p298QT8w4rTuIoAx0uQey/CHujDmOJhd6aTtbcTmEOsTwqRoqUQLUVxwiCBN2O8\n83e/WAZRf3NuD4QmuMhxcM2bOqK7nTJUt3ElUDTrMBClVB1w9aZ/4a8CgYEAy0BX\n2pm0ZVMZGH5aQfuhCW3nMM32C1OMyZldd0buKezBR/AhIt9KeYsO9hhpMKpU5gVb\nFCcP3Zt0LeTnqBaFxZVdsMrmf99t8gJitxiCC2hYKTHN4Sh+0E6kgDvDn6PcsAFF\nxlQZ6hNKdbVBM+ap/ZSCjZfPynDjwTbLY+bSVVkCgYEApVQ1gNLMnMj36wTW2Rf3\nFw/n2JoXUZv/2gLkvwfLqjf/yvTpH7QNEAS8iX8ubq31KbOBBf5nzLO40FVmRWTt\ny7bNxQPcjakwAkOJKz1MbqThn1GdMFgxhGMQit4KPPA5+WPNoJ5ATsLsaoX7okiY\nqDcl7Wls0mLPaSRs8HEsXeMCgYBNZlJOZ6v/zfZHko5ShD1d9uFMf5JL2+RIPUQP\nkQ5PHt63w2UK/5c/08m9w6wDIUo1UiLN+NYc4P8MHxhstS76ABhuo8XFOlOHDouD\nCC01pOW1wkaRkLdCIkCYqKmlWGRJDiMBFLPNpMz9KCoNVrCzZWOWAhLaF8VTpccs\nYxED+QKBgQCitFftytbxhZ3jK7muUVcyDjLZIsmB4CCJkB/edBRXSxgPeuDByU3f\nxKBywKeiThsXWny6JTwwmXE/MbrTVjV5wUPbQhp8l5Ha4cVDPpHyTQhcOYRbXD58\n1N7AyD5x1XcNdWgAjKSbNAWa4fO7NAym0ioY0dXU8Nsg9F41UKW0dw==\n-----END RSA PRIVATE KEY-----\n",
       public_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCxXKR0w6tUaaJffRnJeani6qCaqJtrsKEbDu8J6MNwpsohkwL7XeylDFxcwlRX4wOcOXkNMQssGCUiIu/s9akA3Nqpp0WeDQ0d4G0RsvA7mrKm7ok1DhMEv02wRkZ7nbgSSATV70Ndlem5znkm6gW4jJR3Df3KvkBMsj7kkTRhYQE/hg3TbtZUaYw6OdYM8LHOnz2D3JmDGX2doap+NzJe881FOUfp8cAIStePv8gb51yCfyBH0hIxfVl0I9jUbYNwuqavzzqvcywn/Cb1SzDw+H9iK8h8Dk4bKfua8ahh2aD77/mtK/nluvN+GgXQxZfu+vco+/LSXbcrWwaz8pDX",
       public_key_fingerprint: "58:cb:1a:43:28:83:7e:c3:32:11:f1:b6:a9:98:3d:0e"
       }' \
  -v web_ip=10.0.0.200 \
  -v worker_key='{
       private_key: "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAywz7HF45lYG/I6QPpHyQtCQXTniG8GOQ3MU1KOFTqR0APVXj\nwoE08MVxmyXNIibLmYYPFzOZFhy6KRvO8gOveZxaFIFZCtUa4/jDNkpad69NJJ8G\ntPcqxPZOuHnhyABWSmhJcwrHK0SWmCuOlAoWs4qftxADgBtRlfeQys9ETslTYpdE\nmi6GhOwL1VurCl6PV77nc2NROcYNnxdVL9js9Sm8+/i6wW8wDdMPVIrPq8/LJBlK\nqJspcu1JFT8kvft1f/TUMkEpj3j4Brd7ID0cABXn798UIq8DlVH3CWBZx5SPeSAt\nDKHOoyLdPz+cvemLRBTEuD+6f1i4RW8UiGgS9wIDAQABAoIBAQCIp6zc88FXkKHe\nT81DS55rzpps8osGgEv/eS4E3FlcyKrfnM2TmzfRD2EdJLzBTlDaezHu0IgoLJ9R\niWim0ronY4XwpPkTZEcbxNFE2Ze3UyDdE7YE1xBOzOJAH69H1oo8u6ErLsbKpPeh\nZDcqBPwwS4ygPMPOVRR8lMg65nG3f26LG2NkG7RnE6sVvYZjKKrs9PboaL8AMNNP\n39WBgEUBD5VJXcU6+lyaKX5E06iiCML7uWM8OyyLKC9ppmu3l5MC9P/rjbfRQZaH\ntUVg0fZBB3pRVNibu1tPgiLeffBuzdQHmr5XInsIp32ZF4xFL74VvoRaMieZwKFg\nXL9PjtjJAoGBAN7t7qp+EWoXB/d2a5hVGGUfbTlOp57/RGRd/vqEJZ8Owe49JxKJ\nzoJUAwmBW72MmsDfTZTgurk806E0opPSxmBvfI21Ewb4QUvmR7allkuT7YBVSDeV\nsJvC3igyhc5U1Nr2EBe5/Onil3AYXtWXGvXwKgAdXDgOoCNjaCl3F8PTAoGBAOks\nICU99mUb63AtXhUnSHZ81LayTtmjdmMA6zDGZoH72pqu5ejqrIP63TCO9R1QXYd4\npC3GuaI2IXzqqM4DJzrzQIim8slQC69A3XVDwTjj0+DIRDBRSB9twUjF9YuxiSXZ\n7YU4W8jYa2Xnrri36hTXIElnXPGDZylPdMkK29HNAoGAWcLL2nIwaNslJgrUf92j\nmPPycqSs8WQvEYqXZB9ZVpYGl/qfhONf9zIElwsy+TtoBEjlYBCsnnFTdRFQdNzl\na2b4a8aBBslm4Tyzm2NJBN1nP8kW7uqi1dS8xsqw/cdCfXeeOy90GmhWOZhWdwIE\npQoynyEzRI7/A8C+7BM7ymkCgYEAh5rT7xTEETVVjV21E5RO/inHA6FbXhNErHtC\nTJF12C6Ciechan3garkgnjblsnCklD7DLKQgHYhhnWZTWcxXql8Brvd4xz84LGoK\n4UHQQ6er91RA4+DBkxWfjRUjomRToKHHEu0d5AaJHzDIWkELb6dU7ZuhYAvNmSbO\ngoVAJhkCgYBpVlxtpSbhdx3OIK4EHdN9XhIabzi25fBqZotuY100ZykJ9ooNprxt\nGc5VV6uouMeXgTTsB+hsWczoP4x2aywB5YCmxJqZS730J0cl4abxENDOvWdNwao2\nlSD4KeGyMJ/DI+pHeIlI3XIPptNLJJwx/7hiBKC8QTUsSeRU9N2kfg==\n-----END RSA PRIVATE KEY-----\n",
       public_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLDPscXjmVgb8jpA+kfJC0JBdOeIbwY5DcxTUo4VOpHQA9VePCgTTwxXGbJc0iJsuZhg8XM5kWHLopG87yA695nFoUgVkK1Rrj+MM2Slp3r00knwa09yrE9k64eeHIAFZKaElzCscrRJaYK46UChazip+3EAOAG1GV95DKz0ROyVNil0SaLoaE7AvVW6sKXo9XvudzY1E5xg2fF1Uv2Oz1Kbz7+LrBbzAN0w9Uis+rz8skGUqomyly7UkVPyS9+3V/9NQyQSmPePgGt3sgPRwAFefv3xQirwOVUfcJYFnHlI95IC0Moc6jIt0/P5y96YtEFMS4P7p/WLhFbxSIaBL3",
       public_key_fingerprint: "df:49:f6:e8:0c:b9:0c:c2:39:97:a5:02:06:1a:f6:c8"
       }' \
;
exit
#bosh create-env bosh-deployment/bosh.yml \
#  --state state/bosh-deployment-state.json \
#  -o bosh-deployment/openstack/cpi.yml \
#  -o bosh-deployment/openstack/keystone-v2.yml \
#  -o bosh-deployment/uaa.yml \
#  -o bosh-deployment/credhub.yml \
#  -o opsfiles/bosh-disk-pools.yml \
#  -v admin_password=admin \
#  -v api_key=password \
#  -v auth_url=http://$OPENSTACK_IP:5000/v2.0 \
#  -v az=nova \
#  -v default_key_name=bosh \
#  -v default_security_groups=[bosh] \
#  -v director_name=bosh \
#  -v internal_cidr=$PRIVATE_CIDR \
#  -v internal_gw=$PRIVATE_GATEWAY_IP \
#  -v internal_ip=$PRIVATE_IP \
#  -v net_id=$PRIVATE_NETWORK_UUID \
#  -v openstack_domain=nova \
#  -v openstack_password=password \
#  -v openstack_project=demo \
#  -v openstack_tenant=demo \
#  -v openstack_username=admin \
#  -v private_key=../state/bosh.pem \
#  -v region=RegionOne \
#  --vars-store state/bosh-creds.yml \
#  --tty \
#;

bosh alias-env --ca-cert <(bosh interpolate state/bosh-creds.yml --path /director_ssl/ca) -e $PRIVATE_IP bosh
bosh log-in -e bosh --client admin --client-secret admin

CF_STEMCELL_VERSION=$(bin/bosh int cf-deployment/cf-deployment.yml --path /stemcells/alias=default/version)
bosh upload-stemcell -e bosh \
  --name=bosh-openstack-kvm-ubuntu-trusty-go_agent \
  --version=$CF_STEMCELL_VERSION \
  https://bosh.io/d/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent?v=$CF_STEMCELL_VERSION

bosh update-cloud-config -e bosh --non-interactive state/cloud-config.yml

# CF
bosh deploy -e bosh  -d cf cf-deployment/cf-deployment.yml \
  -o cf-deployment/operations/scale-to-one-az.yml \
  -o cf-deployment/operations/test/alter-ssh-proxy-redirect-uri.yml \
  -o opsfiles/cf-cc-disk-quota.yml \
  -v system_domain=$SYSTEM_DOMAIN \
  --vars-store state/cf-creds.yml \
  -n \
;


# Concourse
bosh deploy -e bosh -d bosh-concourse bosh-concourse-deployment.yml \
  --vars-store state/concourse-creds.yml \
  -n \
;
