#!/bin/bash
subscription-manager register --force --auto-attach --username="xxxxxxxx" --password="XXXXXXXXXXXX" 
yum update -y
subscription-manager unregister
