#!/usr/bin/env bash
IMAGES_DIR="/var/lib/libvirt/images"
OFFICIAL_IMAGE=${IMAGES_DIR}/rhel7-guest-official.qcow2
PASSWORD_FOR_VMS='XXXXXXXXXXX'
VIRT_DOMAIN='khome.net'

if [ -z $1 ];then
	echo "Usage: setup-base <vm-name> <4th-Octet"
	exit
fi
IP="$2"
export LIBGUESTFS_BACKEND=direct

### Let the user know that this will destroy his environment.

ANSWER=YES
echo "Looking for previous builds"
if virsh list --all | egrep -q  "base-$1"
then
  unset ANSWER
  echo '*** WARNING ***'
  echo 'This procedure will destroy the environment you currently have'
  echo 'Type uppercase YES if you understand this and want to proceed'
  echo 'The following VMs will be lost forever'
  virsh list --all | egrep  "base-$1"
  read -p 'Your answer > ' ANSWER
fi

[ "${ANSWER}" != "YES" ] && exit 1

echo "Destroying old vms"
if virsh list --all | egrep -q  'base-$1'
then
	for VM in $(virsh list --all | awk /base/'{print $2}')
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

RAM=8192
CORES=2

VM=base-$1
qemu-img create -f qcow2 -o preallocation=metadata ${IMAGES_DIR}/${VM}.qcow2 100G
qemu-img create -f qcow2 -o preallocation=metadata ${IMAGES_DIR}/${VM}-storage1.qcow2 40G
cat > /tmp/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
IPADDR=192.168.122.$IP
NETMASK=255.255.255.0
GATEWAY=192.168.122.1
NM_CONTROLLED="no"
DNS1=192.168.122.1 
EOF
echo -e "192.168.122.$IP\t\t$VM" >> /etc/hosts
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
	--noautoconsole --vnc --network network:default \
	--name ${VM} \
	--cpu host,+vmx \
	--dry-run --print-xml > /tmp/${VM}.xml
virsh define --file /tmp/${VM}.xml
#rm /tmp/${VM}.xml
virsh start ${VM}

mkdir /tmp/base-host-setup
echo "$VM ansible_user=root ansible_ssh_extra_args=\'-o StrictHostKeyChecking=no\'" > /tmp/base-host-setup/base-inventory
cp base-host-setup.yaml /tmp/base-host-setup/
chmod 666 /tmp/base-host-setup/*
cd /tmp/base-host-setup/
sudo -u scott ansible-playbook -i base-inventory base-host-setup.yaml

