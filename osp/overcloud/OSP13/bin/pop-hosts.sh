#!/bin/bash
sudo sed  -i "/.*overcloud.*/d" /etc/hosts
source ~/stackrc
for i in $(openstack server list -c Name -f value); do 
	IP=$(openstack server show ${i} -c addresses -f value | awk -F= '{print$2}')
	echo -e "${IP}\t${i}"
done | sudo tee -a /etc/hosts

