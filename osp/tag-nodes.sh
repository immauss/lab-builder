#!/bin/bash
##########################################################################
#                                                                        #
#                          Common Functions                              #
#                                                                        #
##########################################################################


#
#  Print info message to stderr
#
function echoinfo() {
  printf "${GREEN}INFO:${NORMAL} %s\n" "$*" >&2;
}

#
#  Print error message to stderr
#
function echoerr() {
  printf "${RED}ERROR:${NORMAL} %s\n" "$*" >&2;
}


#
#  Print exit message & exit 1
#
function exit_on_err()
{
  echoerr "Failed to deploy - Please check the output, fix the error and restart the script"
  exit 1
}

. /tmp/osp-lab.conf
  echoinfo "---===== Tag overcloud images =====---"

  echoinfo "Tagging Controller nodes to $CTRL_FLAVOR profile and $CTRL_SCHED scheduler hint..."
  for i in $CTRL_N; do
    echoinfo "Setting up $i..."
    openstack baremetal node set overcloud-$i --property capabilities=profile:${CTRL_FLAVOR},node:${CTRL_SCHED}-${sched_incr},${CTRL_OTHER_PROP} || { echoerr "Setting Ironic properties on node $i failed !"; return 1; }
    ((sched_incr+=1))
  done

  echoinfo "Tagging Compute nodes to $COMPT_FLAVOR profile and $COMPT_SCHED scheduler hint..."
  sched_incr=0
  for i in $COMPT_N; do
    echoinfo "Setting up $i..."
    openstack baremetal node set overcloud-$i --property capabilities=profile:${COMPT_FLAVOR},node:${COMPT_SCHED}-${sched_incr},${COMPT_OTHER_PROP} || { echoerr "Setting Ironic properties on node $i failed !"; return 1; }
    ((sched_incr+=1))
  done

  echoinfo "Tagging Ceph nodes to $CEPH_FLAVOR profile and $CEPH_SCHED scheduler hint..."
  sched_incr=0
  for i in $CEPH_N; do
    echoinfo "Setting up $i..."
    openstack baremetal node set overcloud-$i --property capabilities=profile:${CEPH_FLAVOR},node:${CEPH_SCHED}-${sched_incr},${CEPH_OTHER_PROP} || { echoerr "Setting Ironic properties on node $i failed !"; return 1; }
    ((sched_incr+=1))
  done
