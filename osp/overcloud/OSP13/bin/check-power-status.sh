#!/bin/bash
#Node names to watch: This is a '|' seperated list of partial or complete names to watch and is case sensitive
CTRLNAME="ctrl"
COMPNAME="comp"
WATCH="$CTRLNAME.*power.on|$COMPNAME.*power.on"
# time in second to wait between checks. To frequently can effect undercloud performance.
DELAY="5"   
source ~/stackrc
while true; do 
     openstack baremetal node list | tee /tmp/power-check.tmp
     echo "###################### Power on the below nodes ################"
     echo
     if egrep $WATCH /tmp/power-check.tmp; then
	echo -ne "\a"; sleep 1; echo -ne "\a"
     fi
     sleep $DELAY
     clear
done

	
	
	
