#!/bin/bash
time openstack overcloud deploy \
     --templates /usr/share/openstack-tripleo-heat-templates/ \
     -e ~/templates/inject-trust-anchor.yaml \
     -e ~/templates/single-node-config.yaml
