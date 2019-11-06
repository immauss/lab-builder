#!/bin/bash
. ~/overcloudrc
echo "Creating external network"
openstack network create --external --share --provider-network-type flat --provider-physical-network datacentre external

openstack subnet create \
 --gateway 172.16.0.1 \
 --allocation-pool start=172.16.0.151,end=172.16.0.200 \
 --no-dhcp \
 --network external \
 --subnet-range 172.16.0.0/24 \
 external
if ! [ -f ~/images/cirros.img ]; then
	echo "Downloading cirros image"
	curl -o ~/images/cirros.img http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
else
	echo "using existing cirros image"
fi

echo "Loading cirros image in overcloud"
cd images
qemu-img convert -f qcow2 -O raw cirros.img cirros.raw
openstack image create --disk-format raw --container-format bare --public --file cirros.raw cirros

echo "Creating Flavors, users and project"

if ! openstack flavor list | grep my.tiny; then 
	openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny
fi

openstack project create test
openstack user create --project test --password redhat test
openstack role add --user test --project test _member_
openstack role add --user test --project test Member
openstack role add --user test --project test admin


openstack flavor list
cd
echo "start using new user and project"
sed -e 's/=admin/=test/' -e 's/OS_PASSWORD=.*/OS_PASSWORD=redhat/' ~/overcloudrc > ~/testrc
. ~/testrc

echo "create network in project"
openstack network create test

openstack subnet create \
 --network test \
 --gateway 192.168.123.254 \
 --allocation-pool start=192.168.123.1,end=192.168.123.253 \
 --dns-nameserver 8.8.8.8 \
 --subnet-range 192.168.123.0/24 \
 test

echo "Creating routers in project"
openstack router create test

neutron router-gateway-set test external

neutron router-interface-add test test

echo "Creating security groups and rules"
openstack security group create --project test test
openstack security group rule create \
 --ingress \
 --ethertype IPv4 \
 --protocol tcp \
 --dst-port 22 \
test 

openstack security group rule create --ingress --ethertype IPv4 --protocol icmp test

openstack keypair create --public-key ~/.ssh/id_rsa.pub stack

floatip=$(openstack floating ip create external | awk /floating_ip_address/'{print $4}')

echo -e "\aCreating instance in test project"

openstack server create \
 --flavor m1.tiny \
 --image cirros \
 --key-name stack \
 --security-group test \
 --nic net-id=test \
 test

openstack server list 

echo "adding floating IP"
openstack server add floating ip test $floatip
echo $floatip

openstack server list

echo "\a Make sure you can ping and ssh to the Floating IP $floatip"
ping -c 5 $floatip
echo "ssh cirros@$floatip"
