#!/bin/bash
time openstack overcloud deploy --templates \
  -e /home/stack/templates/node-config-ceph.yaml \
  -e /home/stack/templates/ceph-ansible/ceph-ansible.yaml \
  -e /home/stack/templates/ceph-ansible/ceph-rgw.yaml \
  -e /home/stack/templates/ceph-ansible/ceph-mds.yaml \
  -e /home/stack/templates/cinder-backup.yaml \
  -e /home/stack/templates/ceph-config.yaml  | tee deploy-$(date +%s).log
