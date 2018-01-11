#!/bin/bash
set -ex

case `whoami` in

root)
# required for private network routing
# TODO: change to use ens32 instead
iptables -t nat -A POSTROUTING -o ens192 -j MASQUERADE

# set up stack user
useradd -m -s /bin/bash stack
echo -e "stack ALL=(ALL) NOPASSWD:ALL\nDefaults:stack !requiretty" > /etc/sudoers.d/0-stack
chmod 0777 $0
su -l stack `pwd`/$0

;;

stack)
host_ip="10.10.0.4"
network_interface=ens32
GIT_BASE="https://github.com"

DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update || sudo yum update -qy
DEBIAN_FRONTEND=noninteractive sudo apt-get install -qqy git htop || sudo yum install -qy git htop

sudo chown stack:stack /home/stack
cd /home/stack
git clone --branch=stable/newton $GIT_BASE/openstack-dev/devstack.git
cd devstack

cat > local.conf <<EOF
[[local|localrc]]
ADMIN_PASSWORD=password
DATABASE_PASSWORD=password
RABBIT_PASSWORD=password
SERVICE_PASSWORD=password

VOLUME_BACKING_FILE_SIZE=102400M

CINDER_BRANCH=newton-eol
GLANCE_BRANCH=newton-eol
HORIZON_BRANCH=newton-eol
KEYSTONECLIENT_BRANCH=newton-eol
KEYSTONE_BRANCH=newton-eol
NEUTRON_BRANCH=newton-eol
NOVACLIENT_BRANCH=newton-eol
NOVA_BRANCH=stable/newton
REQUIREMENTS_BRANCH=stable/newton
SWIFT_BRANCH=newton-eol

## Neutron options
Q_USE_SECGROUP=True
FIXED_RANGE=10.0.0.0/24
FLOATING_RANGE=172.18.161.0/24
PUBLIC_NETWORK_GATEWAY=172.18.161.1
PUBLIC_INTERFACE=$network_interface

# Disable unused services
disable_service n-novnc

# Speedups
GIT_BASE="$GIT_BASE"
EOF

cat > post-stack.sh <<EOF
#IP forward rules
source ./openrc admin demo

#Bosh
openstack quota set demo --instances 25
openstack quota set demo --cores 25
openstack quota set demo --volumes 20
openstack quota set demo --ram 122880
cat > id_bosh_rsa.pub <<EOF2
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDjiROOp2ClfiN0/9k+le/jMqHTI0/akgggCZ2hDf9aGhNFaVwdnU/yrKtCIobYv6LPX/uwQBwXUgWQ5ezlffe79RWJs7OQYEsN8aOSlqcBqfap0f2K0sQpU9jYvJuUdOw/pzpHAGo5yFlW8oCSJke/DU3LGqJkw/CVOCq1pohczVgYiBia0Un4l9CceT22bb2ZxMfy26jw0VtX4cC2UtVyfXI9xjaqbzFCJwQcIe8ECom0e7RLF0aglCSs+gwoRg/HK7NjnFPLVL0CuB4aBD+B6eLtI0LxB1ixcsnRi/UXeLFKfs+jwysUEgcN1H5pY8N/X44yNQ+OkMXZ/7PwpH/d vcap@bosh-init 
EOF2
openstack keypair create --public-key=id_bosh_rsa.pub bosh
openstack security group create bosh
openstack security group rule create bosh --protocol=tcp --dst-port=22
openstack security group rule create bosh --protocol=tcp --dst-port=6868
openstack security group rule create bosh --protocol=tcp --dst-port=8443
openstack security group rule create bosh --protocol=tcp --dst-port=25555
openstack security group rule create bosh --protocol=tcp --src-group=bosh
openstack security group rule create bosh --protocol=udp --src-group=bosh
openstack security group rule create bosh --protocol=icmp #debugging
openstack floating ip create public --floating-ip-address 172.18.161.252
openstack floating ip create public --floating-ip-address 172.18.161.253
openstack floating ip create public --floating-ip-address 172.18.161.254

#Concourse
openstack security group rule create bosh --protocol=tcp --dst-port=8080

#CloudFoundry
openstack security group create cf
openstack security group rule create cf --protocol=udp --dst-port=68
openstack security group rule create cf --protocol=udp --dst-port=3457
openstack security group rule create cf --protocol=icmp
openstack security group rule create cf --protocol=tcp --dst-port=22
openstack security group rule create cf --protocol=tcp --dst-port=80
openstack security group rule create cf --protocol=tcp --dst-port=443
openstack security group rule create cf --protocol=tcp --dst-port=4443
openstack security group rule create cf --protocol=tcp --src-group=cf
openstack security group rule create cf --protocol=udp --src-group=cf
openstack security group rule create bosh --protocol=tcp --src-group=cf
openstack security group rule create bosh --protocol=udp --src-group=cf

#Create minimal flavor
openstack flavor delete m1.small
openstack flavor delete m1.medium
openstack flavor delete m1.large
openstack flavor delete m1.xlarge
openstack flavor create m1.director --public --vcpus 1 --ram 2048 --disk 15
openstack flavor create m1.small --public --vcpus 1 --ram 1024 --disk 10
openstack flavor create m1.medium --public --vcpus 1 --ram 2048 --disk 10
openstack flavor create m1.large --public --vcpus 1 --ram 8192 --disk 15
openstack flavor create m1.xlarge --public --vcpus 1 --ram 16384 --disk 15
openstack flavor create r3.xlarge --public --vcpus 1 --ram 16384 --disk 10 --ephemeral 32

#output private net uuid
openstack network show private -c id
EOF

chmod +x post-stack.sh

./stack.sh
./post-stack.sh
;;

esac

