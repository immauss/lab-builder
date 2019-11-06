#!/bin/bash
time openstack overcloud deploy \
     --templates /usr/share/openstack-tripleo-heat-templates/ \
     -e ~/templates/node-config-1ctr1cmp.yaml | tee deploy-$(date +%s).log
