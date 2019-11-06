#!/usr/bin/env bash

#TODOs
# Fixed IPs
# install  bind-chroot bind-utils vim, ansible on ansible
# setup bind on ansible
# X rename hosts to master,node1,node2,node3
# X add extra raw disk to all nodes for storage
# create /etc/hosts for all IPs
# resolve.conf points to ansible node
# named 
# 	allow any
#	listen all
# 	resolve.conf with search
#	in-addr.arpa
# Make sure DNS gets set to ansible-host in ifcfg-eth0
# Docker storage setup on all nodes
# cat <<EOF > /etc/sysconfig/docker-storage-setup
# DEVS=/dev/vdb
# VG=docker-vg
#EOF
# docker-storage-setup 
# systemctl enable docker; systemctl start docker ; systemctl status docker 





IMAGES_DIR=/var/lib/libvirt/images
OFFICIAL_IMAGE=${IMAGES_DIR}/rhel7-guest-official.qcow2
PASSWORD_FOR_VMS='XXXXXXXXXXX'
VIRT_DOMAIN='khome.net'

export LIBGUESTFS_BACKEND=direct

### Let the user know that this will destroy his environment.

ANSWER=YES
echo "Looking for previous builds"
if virsh list --all | egrep -q  'ocp'
then
  unset ANSWER
  echo '*** WARNING ***'
  echo 'This procedure will destroy the environment you currently have'
  echo 'Type uppercase YES if you understand this and want to proceed'
  read -p 'Your answer > ' ANSWER
fi

[ "${ANSWER}" != "YES" ] && exit 1

echo "Destroying old vms"
if virsh list --all | egrep -q  'ocp'
then
	for VM in $(virsh list --all | awk /ocp/'{print $2}')
  do
    echo "Removing $VM"
    virsh destroy ${VM}  > /dev/null 2>&1
    virsh undefine ${VM} > /dev/null 2>&1
    rm -f ${IMAGES_DIR}/${VM}.qcow2 > /dev/null 2>&1
    sed -ie "/$VM/d" /etc/hosts
  done
fi


# Create virtual machines
echo "Creating new VMs"

echo "Updateing 'Offical Image'"
virt-customize -a $OFFICIAL_IMAGE --run ./sub-n-update.sh 


# Setup 4 machines
# ansible, Master, Node1, Node2, Node3

count=1
for node in ansible master node1 node2 node3
do
	VM=ocp-$node
	qemu-img create -f qcow2 -o preallocation=metadata ${IMAGES_DIR}/${VM}.qcow2 100G
	qemu-img create -f qcow2 -o preallocation=metadata ${IMAGES_DIR}/${VM}-storage1.qcow2 40G
	qemu-img create -f qcow2 -o preallocation=metadata ${IMAGES_DIR}/${VM}-cns.qcow2 80G
cat > /tmp/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
IPADDR=192.168.122.20$count
NETMASK=255.255.255.0
GATEWAY=192.168.122.1
NM_CONTROLLED="no"
DNS1=192.168.122.1 
EOF
	echo -e "192.168.122.20$count\t\t$VM" >> /etc/hosts
	if [ $count -gt 1 ]; then
		RAM="16384"
		CORES="6"
	else
		RAM="8192"
		CORES="2"
	fi
	virt-resize --expand /dev/sda1 ${OFFICIAL_IMAGE} ${IMAGES_DIR}/${VM}.qcow2
	virt-customize -a ${IMAGES_DIR}/${VM}.qcow2 \
  	  --hostname $VM.khome.net \
  	  --root-password password:${PASSWORD_FOR_VMS} \
  	  --uninstall cloud-init \
  	  --copy-in /tmp/ifcfg-eth0:/etc/sysconfig/network-scripts/ \
  	  --ssh-inject root:file:/home/scott/.ssh/id_rsa.pub \
  	  --copy-in /home/scott/.ssh/id_rsa:/root/.ssh/ \
  	  --copy-in /home/scott/.ssh/id_rsa.pub:/root/.ssh/ \
  	  --run-command 'chown root:root /root/.ssh/id_rsa' \
  	  --run-command 'chown root:root /root/.ssh/id_rsa.pub' \
     --selinux-relabel
	virt-install --ram $RAM --vcpus $CORES --os-variant rhel7 \
	--disk path=${IMAGES_DIR}/${VM}.qcow2,device=disk,bus=virtio,format=qcow2 \
	--disk path=${IMAGES_DIR}/${VM}-storage1.qcow2,device=disk,bus=virtio,format=qcow2 \
	--disk path=${IMAGES_DIR}/${VM}-cns.qcow2,device=disk,bus=virtio,format=qcow2 \
	--noautoconsole --vnc --network network:default \
	--name ${VM} \
	--cpu host,+vmx \
	--dry-run --print-xml > /tmp/${VM}.xml
	virsh define --file /tmp/${VM}.xml
	#rm /tmp/${VM}.xml
	virsh start ${VM}
	count=$( expr $count + 1)
done
#mark=0
#echo "Waiting for VMs to start"
#while [ $mark -lt 60 ]; do 
#	echo -n "."
#	mark=$( expr $mark + 1)
#done

mkdir /tmp/ocp-host-setup
cp ocp-inventory ocp-host-setup.yaml docker-storage-setup /tmp/ocp-host-setup/
chmod 666 /tmp/ocp-host-setup/*
cd /tmp/ocp-host-setup/
sudo -u scott ansible-playbook -i ocp-inventory ocp-host-setup.yaml

