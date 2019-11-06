#!/bin/bash
time openstack overcloud deploy \
     --templates /usr/share/openstack-tripleo-heat-templates/ \
     -e ~/templates/custom-config.yaml \
     -e ~/templates/node-config.yaml
