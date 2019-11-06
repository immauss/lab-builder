#!/bin/bash
sudo sed  -i "/.*overcloud.*/d" /etc/hosts
rm -f inventory
source ~/stackrc
for i in $(openstack server list -c Name -f value); do 
	IP=$(openstack server show ${i} -c addresses -f value | awk -F= '{print$2}')
	echo -e "${IP}\t${i}" | sudo tee -a /etc/hosts
	echo -e "${i}\tansible_user=heat-admin ansible_ssh_extra_args='-o StrictHostKeyChecking=no" | tee -a inventory
done 

