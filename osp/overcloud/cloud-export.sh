#!/bin/bash
IMAGE_DIR=/var/lib/libvirt/images
DEST_DIR=/mnt/kvm-exports
VMS=$(virsh list --all | awk /overcloud/'{printf " "$2}')
VMS="$VMS undercloud"
echo "Exporting $VMS to $DEST_DIR as xml"
echo "Ready?"
read junk
for vm in $VMS; do 
	echo "Exporting $vm to $DEST_DIR"
	virsh dumpxml $vm > $DEST_DIR/$vm.xml
done
IMAGES=$(ls $IMAGE_DIR/overcloud*.qcow2)
echo " Exporting disk images $IMAGES to $DEST_DIR"
echo " Ready?"
read junk
for file in $IMAGES undercloud.qcow2 ; do 
	qemu-img  convert -p -O qcow2 $file $DEST_DIR/$(basename $file)
done

