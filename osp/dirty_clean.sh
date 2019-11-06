#!/bin/bash

# Dirty clean up

if vbmc --version; then
  echo "Removing VBMC entries"
  for i in $(virsh list --all | awk ' /overcloud/ {print $2}'); do
    echo "Removing VBMC entry for VM $i"
    #systemctl stop virtualbmc@${i}
    #systemctl disable virtualbmc@${i}
    vbmc delete $i
  done

  #rm -f /usr/lib/systemd/system/virtualbmc@.service
  #rm -f /etc/systemd/system/multi-user.target.wants/virtualbmc@*

  systemctl daemon-reload
  pkill -KILL vbmc
fi


for i in $(virsh list --all | grep cloud |  awk '{print $2}'); do

     # delete the snapshots
     for j in $(virsh snapshot-list $i | awk ' /cloud/ { print $1 } ')
     do
        echo "Deleteing snapshot $j of $i"
        virsh snapshot-delete $i $j
     done

     echo "shuting down $i"
     virsh destroy $i &> /dev/null || echo "$i is not running, skipping"
     echo "Deleting $i"
     virsh undefine $i
done


echo "cleaning up /var/lib/libvirt/images/"
#rm -f /var/lib/libvirt/images/*
rm -f /var/lib/libvirt/images/overcloud*
rm -f /var/lib/libvirt/images/undercloud*

for net in provisioning trunk ospdflt; do 

	echo "Stopping $net net"
	virsh net-destroy $net
	echo "Deleting $net net"
	virsh net-undefine $net
done

#echo "Restoring DHCP to default  net"
#virsh net-update default add ip-dhcp-range "<range start='192.168.122.2' end='192.168.122.254'/>" --live --config

echo "Deleting docker IDM container"
docker rm -f idm

echo "Deleting docker image"
docker rmi idm
docker rmi registry.access.redhat.com/rhel7/ipa-server

#echo "Deleting dummy0 interface"
#ifdown dummy0
#rm -f /etc/sysconfig/network-scripts/ifcfg-dummy0
nmcli con del dummy0
#modprobe -r dummy

#subscription-manager unregister
