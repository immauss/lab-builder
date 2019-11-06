# lab-builder
A big pile of scripts and templates to help build OpenStack Environments. The target is a single libvirt host with minimum of 96G of RAM. 128 Is prefered. Node memory requirements are adjustable in the conf.</br>
Currently includes templates for:</br>
- OSP 10
  -  3 Controller 2 compute 3 Ceph
- OSP 13
  -  1 Compute 1 Controller
  -  3 Controller 2 compute
  -  3 Controller 2 compute 3 Ceph
- OSP 14
  -  1 Compute 1 Controller
  -  3 Controller 2 compute 3 Ceph
  
  
  
  <b>To Do</b>
  - Need to get RHEL8 bits for OSP 15+
    - Check for OSP version & change repos
    - Check for OSP version & pull RHEL 8 base images
  - Adjust docs and help for changes
  -BUG: After rebooting the KVM host, the vbmc fails during overcloud-register, but only the first time.
