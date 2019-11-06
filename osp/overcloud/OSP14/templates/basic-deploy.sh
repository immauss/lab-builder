#!/bin/bash
time openstack overcloud deploy \
     --templates /usr/share/openstack-tripleo-heat-templates/ \
     -e ~/templates/node-config.yaml
