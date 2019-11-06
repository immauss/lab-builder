#!/bin/bash
time openstack overcloud deploy \
     --templates /usr/share/openstack-tripleo-heat-templates/ \
     -e ~/templates/single-node-config.yaml
