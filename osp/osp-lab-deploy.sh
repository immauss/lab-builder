h!/bin/bash
#
#
#   Field PM Team - Please send your feedback/bugs to Gregory Charot - gcharot@redhat.com
#   This version is a Fork of the Gregory Charot. It has a few differences:
#		1. It does not reuse the default network of 192.168.122, but creates a new ospdflt network.
#        This allows you to continue using the default network with DHCP wiht other things that expect it. 
#     2. It assumes you have already installed vbmc. This is because it will not be availabe in future RHEL release
#        due to incompatible dependencies. 
#     3. The accompanying "dirty_clean.sh" no longer removes all images from your image storage.
#		4. Fixed some issues with rhn
#		5. vbmc uses different ports per vm instead of using the dummy modules to create extra interfaces. 
#		6. This will work fine if you run it on Fedora (Built and tested on 29)
#		7. There are few more packages installed by default (tmux for one)
VERSION=1.0SK

if ! [ -f osp-lab.conf ]; then
cat << EOF > osp-lab.conf
######## PLEASE REVIEW ALL OPTIONS BELOW BEFORE RUNNING THE SCRIPT #########


##########################################################################
#                                                                        #
#                        Subscription management                         #
#                                                                        #
##########################################################################


# How do you want to register the systems ?
# ACCEPTED values are "rhos-release" or "rhn"
# PLEASE double check options below for each case.

SUB_TYPE="sat6"


### For rhos-release only!

RHOS_VERSION=10

### For RHN only!
# WARNING Test coverage of this feature is limited
# The script will attach your employee subscription

# Your RHN login
RHN_USERNAME="xxxxxxxx"
# Your RHN password - will be asked interactively if left empty
RHN_PASSWD="XXXXXXXXXXXX"
# RHEL Major Version
RHEL_MAJ_VERSION="7"
# RH-OSP major version
OSP_MAJ_VERSION="10"

#### For Sat 6 only
SatKEY="osp10"
SatORG="Default_Organization"
SatServer="sat6.khome.net"

##########################################################################
#                                                                        #
#                          Environment Definitions                       #
#                                                                        #
##########################################################################

### IRONIC Driver
# Accepted values are ssh|vbmc
# pxe_ssh NOT supported starting OSP12
# Default: vbmc

IRONIC_DRIVER="vbmc"

### VM Memory (GB) and vCPU settings

# Undercloud
UNDERC_MEM='16384'
UNDERC_VCPU='4'

# Controllers - 12GB or greater is strongly adviced to avoid OOM errors during deployment
CTRL_MEM='12288'
CTRL_VCPU='4'

# Computes
COMPT_MEM='6144'
COMPT_VCPU='4'

# Ceph OSDs
CEPH_MEM='4096'
CEPH_VCPU='4'
# Number of additional disks (OSDs/Journals) to attach to Ceph nodes. Default is 3 AND minimum is 1 - This value does NOT include the O.S disk which is handled automatically.
CEPH_OSD_DISK=3

# Custom nodes
CUST_MEM='4096'
CUST_VCPU='2'

### Overcloud node's list ###

# IMPORTANT #

# !!!!! You can add new nodes by adding them to the relevant type !!!
# For example to add a 4th ceph node please set
# CEPH_N="ceph01 ceph02 ceph03 ceph04"

CTRL_N="ctrl01 ctrl02 ctrl03"
COMPT_N="compute01 compute02"
CEPH_N="ceph01 ceph02 ceph03"
CUST_N="custom01"

# DO NOT change ALL_N variable !
ALL_N="\$CTRL_N \$COMPT_N \$CEPH_N \$CUST_N"

### IDM Configuration

# DEPLOY_IDM="yes" will deploy an IDM container on the hypervisor. IDM will be configured with FQDN: ipa.redhat.local. admin password is "redhat42" The undercloud will be configured to use this IDM.
DEPLOY_IDM="no"
IDM_IMAGE="registry.access.redhat.com/rhel7/ipa-server"
# IDM "external" bind IP, this IP must be exposed by the hypervisor. Default is to use a dummy IP (available only if IRONIC_DRIVER="vbmc")
IDM_BIND_IP="192.168.123.1"

### Overcloud's node ironic properties ###

# Defaults work for most cases

# Controller's nodes Ironic flavor
CTRL_FLAVOR="control"
# Controller's nodes scheduler hint - MUST NOT BE EMPTY - You can decide not to use in your THT.
CTRL_SCHED="controller"
# Controller's nodes extra properties. Add commas as needed
CTRL_OTHER_PROP="boot_option:local"

# Compute's nodes Ironic flavor
COMPT_FLAVOR="compute"
# Compute's nodes scheduler hint - MUST NOT BE EMPTY - You can decide not to use it in your THT.
COMPT_SCHED="compute"
# Compute's nodes extra properties. Add commas as needed
COMPT_OTHER_PROP="boot_option:local"

# Ceph's nodes Ironic flavor
CEPH_FLAVOR="ceph-storage"
# Ceph's nodes scheduler hint - MUST NOT BE EMPTY - You can decide not to use it in your THT.
CEPH_SCHED="ceph"
# Ceph's nodes extra properties. Add commas as needed
CEPH_OTHER_PROP="boot_option:local"

# Custom's nodes Ironic flavor
CUST_FLAVOR="networker"
# Custom's nodes scheduler hint - MUST NOT BE EMPTY - You can decide not to use it in your THT.
CUST_SCHED="networker"
# Custom's nodes extra properties. Add commas as needed
CUST_OTHER_PROP="boot_option:local"

### Misc options

LIBVIRT_D="/var/lib/libvirt/"
RHEL_IMAGE_U="http://localhost/rhel7-guest-official.qcow2"

# You can add new packages to the hypervisor or undercloud system.
PKG_HYPERVISOR="screen tmux wget libvirt qemu-kvm virt-manager virt-install libguestfs-tools libguestfs-xfs xorg-x11-apps xauth virt-viewer xorg-x11-fonts-* net-tools ntpdate mlocate sshpass squid ipmitool python-setuptools libvirt-python redhat-rpm-config python2-devel "
PKG_UNDERCLOUD="screen tmux wget mlocate facter python-tripleoclient libvirt libguestfs-tools openstack-utils sshpass crudini ceph-ansible vim vim"

### Passwords: undercloud and overcloud images ROOT PASSWORD are set to "redhat"
EOF
  echo "Created the config file, osp-lab.conf. Edit this for your environment then rerun."

exit 

fi


. osp-lab.conf 

##########################################################################
#                                                                        #
#                               Miscellaneous                            #
#                                                                        #
##########################################################################

### Ensure $TERM is defined.
if [ "$TERM" = "dumb" ]; then export TERM="xterm-256color"; fi

### Fancy colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)


WHO_I_AM="$0"


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

#
# Help function
#

function help() {
  >&2 echo "Usage : osp-lab-deploy [action]

Deploy and configure virtual Red Hat Openstack Director lab - Version $VERSION

ACTIONS
========
    libvirt-deploy         Configure hypervisor and define VMs/Virtual networks
    idm-deploy             Deploy Red Hat IDM (IPA) as container on the hypervisor.
    undercloud-install     Prepare the undercloud base system for deployment
    overcloud-register     Upload overcloud images to glance and register overcloud nodes to Ironic.
    howto                  Display a quick howto
"
}

function howto()
{
  >&2 echo "
  ----- How to use osp-lab-deploy -----

You are using osp-lab-deploy version $VERSION

Synopsis
========
    The program deploys a virtual enviroment ready to use for playing with Red Hat Director.
    Virtual enviroment is based on KVM/Libvirt - By default, 10 VMs will be defined + 1 Provisioning Network.
    * 1 Undercloud VM
    * 3 Controllers VMs
    * 2 Compute VMs
    * 3 Ceph VMs
    * 1 Custom node (Networker profile by default)

    Please NOTE that the script will only deploy the undercloud, other VMs are blank, ready to be deployed by Red Hat Director.
    You can customise the number of VMs of their configuration by editing the script and setting the appropriate options.

    Optionally you can setup a IDM container if you want to deploy OSP with TLS everywhere.

Automation
==========
    If you want to automate the whole process please use smack-my-node-up.sh
    See https://gitlab.cee.redhat.com/gcharot/osp-enablement-tools/blob/master/deployment-tools/smack-my-node-up.sh

Pre-requisites
==============

    - A baremetal hypervisor with a pre-installed RHEL system, a minimum of 64GB RAM is strongly adviced.
    - Please set the CPU and Memory value for each VM flavor by editing the required variables at the begining of the script.
    - Adjust the number of VMs you would like to define.
    - Likewise set the RHEL and OSP version you would like to use. Default is RHEL 7 and OSP10.


Deploying the environment
=========================

    Deployment is acheived in four steps :

    1) Hypervisor configuration and VM's definition
      - Run \"osp-lab-deploy.sh libvirt-deploy\" as root on the hypervisor
      - REBOOT your hypervisor

    1b) If you want to deploy IDM (DEPLOY_IDM=yes) then
      - Run \"osp-lab-deploy.sh idm-deploy\" as root on the hypervisor

    2) Undercloud preparation
      - SSH into the undercloud node as root \"ssh root@undercloud\"
      - Run \"sh /tmp/osp-lab-deploy.sh undercloud-install\"
      - REBOOT the undercloud VM

    3) Undercloud installation
      - Once rebooted ssh back to the undercloud VM as stack user  \"ssh stackl@undercloud\"
      - Check the ~/undercloud.conf file, modify it if needed.
      - Install the undercloud as stack user \"openstack undercloud install\"

    4) Configure and register nodes
      - Run \"sh /tmp/osp-lab-deploy.sh overcloud-register\" as stack user.
      - Check everything is fine.

    You're all set ! Happy hacking !!!

    Please send feedback and bugs to gcharot@redhat.com

    --- The Field PM Team ---
"

}


#
#  Setup rhos-release
#

function setup_rhos_release()
{

  echoinfo "Installing rhos-release..."

  if (rpm -q rhos-release);
    then
    echoinfo "rhos-release already installed, skipping !"
    echoinfo "Removing current configured repositories"
    yum clean all
    rhos-release -x
  else
    rpm -ivh http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm || { echoerr "Unable to install rhos-realease"; return 1; }
  fi


  # If we are on the hypervisor then install the latest puddles
  # TODO: Do this for RHN...
  if !(grep hypervisor /proc/cpuinfo &> /dev/null);
    then
    echoinfo "Hypervisor detected, installing latest puddle release..."
    rhos-release latest-released || { echoerr "Unable to configure rhos-realease to latest-released"; return 1; }
    return 0
  fi

  echoinfo "Configuring rhos-release to OSP $RHOS_VERSION..."
  rhos-release ${RHOS_VERSION}-director || { echoerr "Unable to configure rhos-realease to ${RHOS_VERSION}-director"; return 1; }

  # Set sub mechanism free OSP major version
  OSP_VERSION=$RHOS_VERSION

}


#
#  Setup RHN
#

function setup_rhn()
{
if [ -f /etc/fedora-release ]; then
	echo "Fedora !!"
	return 0;
fi

  if [ -z $RHN_PASSWD ]; then
    echo -n "No RHN Password submitted please enter your RHN password for account $RHN_USERNAME: "
    read -s RHN_PASSWD
    echo
  fi

  subscription-manager status > /dev/null 
  if [ $? -ne 0 ]; then
  	echoinfo "Registering to RHN..."
  	subscription-manager register --username=$RHN_USERNAME --password=$RHN_PASSWD || { echoerr "Unable to register"; return 1; }
	
  	echoinfo "Looking for Employee SKU POOL ID..."
  	RHN_POOLID=$(subscription-manager list --available --matches="Employee SKU" --pool-only | head -n1)
	
  	if [ -z $RHN_POOLID ];
    	then
    	echoerr "Unable to find Employee SKU POOL ID"
    	return 1
  	else
    	echoinfo "Found POOL ID $RHN_POOLID"
  	fi

  	echoinfo "Attaching pool $RHN_POOLID..."
  	subscription-manager attach --pool=$RHN_POOLID || { echoerr "Unable to attach Employee SKU POOL ID"; return 1; }
  fi

  echoinfo "Configuring repositories..."
  subscription-manager repos --disable=* &>/dev/null
  subscription-manager repos --enable=rhel-${RHEL_MAJ_VERSION}-server-rpms --enable=rhel-${RHEL_MAJ_VERSION}-server-extras-rpms \
--enable=rhel-${RHEL_MAJ_VERSION}-server-rh-common-rpms --enable=rhel-ha-for-rhel-${RHEL_MAJ_VERSION}-server-rpms \
--enable=rhel-${RHEL_MAJ_VERSION}-server-openstack-${OSP_MAJ_VERSION}-rpms || { echoerr "Unable to enable required repositories"; return 1; }
  # RHOSP 14 & up use a seperate repo for ceph tools.
  if [ $OSP_MAJ_VERSION -eq 13 ] || [ $OSP_MAG_VERSION -eq 14 ]; then
	  subscription-manager repos --enable=rhel-7-server-rhceph-3-tools-rpms
  fi
  # This is just one piece of what needs to change for RHOSP5 & up. 
  if [ $OSP_MAJ_VERSION -gt 14 ]; then
	  subscription-manager repos --enable=rhceph-4-tools-for-rhel-8-x86_64-rpms
  fi


  # Set sub mechanism free OSP major version
  OSP_VERSION=$OSP_MAJ_VERSION

}
#
#  Setup Satellite 6
#

function setup_sat6()
{
if [ -f /etc/fedora-release ]; then
	echo "Fedora !!"
	return 0;
fi


  echoinfo "Registering to $SatServer..."
  rpm -ivh http://sat6.khome.net/pub/katello-ca-consumer-latest.noarch.rpm 
  subscription-manager clean  
  subscription-manager register --org $SatORG --activationkey $SatKEY --force || { echoerr "Unable to register"; return 1; }

  echoinfo "Configuring repositories..."
  subscription-manager repos --disable=* &>/dev/null
  subscription-manager repos --enable=rhel-${RHEL_MAJ_VERSION}-server-rpms --enable=rhel-${RHEL_MAJ_VERSION}-server-extras-rpms \
--enable=rhel-${RHEL_MAJ_VERSION}-server-rh-common-rpms --enable=rhel-ha-for-rhel-${RHEL_MAJ_VERSION}-server-rpms \
--enable=rhel-${RHEL_MAJ_VERSION}-server-openstack-${OSP_MAJ_VERSION}-rpms || { echoerr "Unable to enable required repositories"; return 1; }

  # Set sub mechanism free OSP major version
  OSP_VERSION=$OSP_MAJ_VERSION

}
#
#  Install required packages
#

function install_packages()
{
  local pkg_list=$1

  echoinfo "---===== Configuring repositories =====---"

  if [ "$SUB_TYPE" = "rhos-release" ];
    then
    setup_rhos_release || exit_on_err
  elif [ "$SUB_TYPE" = "rhn" ];
    then
    setup_rhn || exit_on_err
  elif [ "$SUB_TYPE" = "sat6" ]; 
    then
    setup_sat6 || exit_on_err
  else
    echoerr "Incorrect registration option specified : $SUB_TYPE - Correct values are rhos-release, sat6 or rhn"
    return 1
  fi

# Check Ironic driver
  if [ "$IRONIC_DRIVER" = "vbmc" ];
    then
    echoinfo "Virtual BMC Ironic driver selected"
  elif [ "$IRONIC_DRIVER" = "ssh" ];
    then
    echoinfo "Pxe SSH Ironic driver selected"
  else
    echoerr "Incorrect Ironic Driver selected : $IRONIC_DRIVER ! Accepted values are ssh or vbmc"
    return 1
  fi


  echoinfo "---===== Installing Packages =====---"

  echoinfo "Updating system..."
  yum update -y || { echoerr "Unable to update system"; return 1; }

  echoinfo "Installing required packages..."
  yum install $pkg_list -y || { echoerr "Unable to install required packages"; return 1; }

}



##########################################################################
#                                                                        #
#                     Hypervisor & Libvirt functions                     #
#                                                                        #
##########################################################################


#
#  Check dependencies + some sanity checks
#

function check_requirements()
{

  # List of command dependencies
  local bin_dep="virsh virt-install qemu-img virt-resize virt-filesystems virt-customize"

  if [ "$IRONIC_DRIVER" = "vbmc" ];
    then
    bin_dep="$bin_dep vbmc"
  fi

  echoinfo "---===== Checking dependencies =====---"

  for cmd in $bin_dep; do
    echoinfo "Checking for $cmd..."
    $cmd --version  >/dev/null 2>&1 || { echoerr "$cmd cannot be found... Aborting"; return 1; }
  done

   echoinfo "---===== Performing sanity checks =====---"

  if [ "$CEPH_OSD_DISK" -lt 1 ];
    then
    echoerr "You need to have at least one additional disk (OSD) attached to your Ceph nodes - Please configure the CEPH_OSD_DISK variable accordingly"
    return 1
  fi

}


#
#  Miscellaneous system config
#

function libv_misc_sys_config()
{

  echoinfo "---===== Misc System Config =====---"


  echoinfo "Creating system user stack..."
  useradd stack

  echoinfo "Setting stack user password to redhat"
  echo "redhat" | passwd stack --stdin

  echoinfo "Configuring /etc/modprobe.d/kvm_intel.conf"
  cat << EOF > /etc/modprobe.d/kvm_intel.conf
options kvm-intel nested=1
options kvm-intel enable_shadow_vmcs=1
options kvm-intel enable_apicv=1
options kvm-intel ept=1
EOF


  echoinfo "Configuring /etc/sysctl.d/98-rp-filter.conf"
  cat << EOF > /etc/sysctl.d/98-rp-filter.conf
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
EOF

  echoinfo "Applying RP filter on running interfaces"
  for i in $(sysctl -A | grep "\.rp_filter"  | cut -d" " -f1); do
   sysctl $i=0
  done

  echoinfo "Configuring  /etc/polkit-1/localauthority/50-local.d/50-libvirt-user-stack.pkla"
  cat << EOF > /etc/polkit-1/localauthority/50-local.d/50-libvirt-user-stack.pkla
[libvirt Management Access]
Identity=unix-user:stack
Action=org.libvirt.unix.manage
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

  echoinfo "Creating SSH keypair"
  if [ -e ~/.ssh/id_rsa ]; then
    echoinfo "SSH keypair already exists, skipping..."
  else
    ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""
  fi

  echoinfo "Starting Libvirtd"
  systemctl start libvirtd || { echoerr "Unable to start libvirtd"; return 1; }

  echoinfo "Ensuring IPTables service is disabled"
  systemctl disable --now iptables.service

  echoinfo "Ensuring firewalld is enabled and running"
  systemctl enable --now firewalld || { echoerr "Unable to start firewalld"; return 1; }


  echoinfo "Configuring Squid"
  # Allow squid client to connect to https servers other than 443
  sed -i 's/\(http_access deny !Safe_ports\)/#\1/; s/\(http_access deny CONNECT !SSL_ports\)/#\1/' /etc/squid/squid.conf
  systemctl enable squid || { echoerr "Unable to enable Squid"; return 1; }
  systemctl start  squid || { echoerr "Unable to start Squid"; return 1; }
  firewall-cmd --permanent --add-service=squid
  firewall-cmd --reload

}


#
# Create new default network w/o DHCP + create provisioning & trunk network
#
function define_virt_net()
{

  echoinfo "---===== Create virtual networks =====---"

cat > /tmp/provisioning.xml <<EOF
<network>
  <name>provisioning</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address="172.16.0.254" netmask="255.255.255.0"/>
</network>
EOF

cat > /tmp/trunk.xml <<EOF
<network>
  <name>trunk</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address="192.168.124.1" netmask="255.255.255.0"/>
</network>
EOF

cat > /tmp/ospdflt.xml << EOF
<network>
  <name>ospdflt</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address='192.168.123.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

for NETWORK in provisioning trunk ospdflt
do
  virsh net-define /tmp/${NETWORK}.xml
  virsh net-autostart ${NETWORK}
  virsh net-start ${NETWORK}
done

#  echoinfo "Disabling DHCP on default network..."
#  if(virsh net-dumpxml default | grep dhcp &>/dev/null); then
#      virsh net-update default delete ip-dhcp-range "<range start='192.168.122.2' end='192.168.122.254'/>" --live --config || { echoerr "Unable to disable DHCP on default network"; return 1; }
#  else
#    echoinfo "DHCP already disabled, skipping"
#  fi
}

#
#  Create generic RHEL image disk
#
function define_basic_image()
{

  echoinfo "---===== Create generic RHEL image =====---"

  pushd ${LIBVIRT_D}/images/
  echoinfo "Downloading basic RHEL image from $RHEL_IMAGE_U..."
  # Commenting this out and leaving the image there to avoid constant downloads
  echoinfo "Or... alternitevly, use the image that is already there ....."  
  #curl -o rhel7-guest-official.qcow2 $RHEL_IMAGE_U || { echoerr "Unable to download RHEL IMAGE"; return 1; }
  cp /root/rhel7-guest-official.qcow2 .
  
  echoinfo "Cloning RHEL image to a 100G sparse image..."
  qemu-img create -f qcow2 rhel7-guest.qcow2 100G || { echoerr "Unable to create sparse clone"; return 1; }


  echoinfo "Checking image disk size..."
  qemu-img info rhel7-guest.qcow2  | grep 100G  &>/dev/null || { echoerr "Incorrect image disk size"; return 1; }

  echoinfo "Extending file system..."
  virt-resize --expand /dev/sda1 rhel7-guest-official.qcow2 rhel7-guest.qcow2 || { echoerr "Unable to extend file system"; return 1; }

  echoinfo "Checking image filesystem size..."
  virt-filesystems --long -h  -a rhel7-guest.qcow2 | grep 100G &> /dev/null || { echoerr "Incorrect image filesystem size"; return 1; }

  echoinfo "Deleting old image..."
  #rm -f rhel7-guest-official.qcow2

  popd
}


#
#  Define & setup undercloud VM
#
function define_undercloud_vm()
{

  echoinfo "---===== Create Undercloud VM =====---"

  pushd ${LIBVIRT_D}/images/
  echoinfo "Create disk from generic image..."

  qemu-img create -f qcow2 -b rhel7-guest.qcow2 undercloud.qcow2 || { echoerr "Unable to create undercloud disk image"; return 1; }

  echoinfo "Customizing VM..."
  virt-customize -a undercloud.qcow2 --root-password password:redhat --ssh-inject "root:file:/root/.ssh/id_rsa.pub" --selinux-relabel --run-command 'yum remove cloud-init* -y && cp /etc/sysconfig/network-scripts/ifcfg-eth{0,1} && sed -i s/ONBOOT=.*/ONBOOT=no/g /etc/sysconfig/network-scripts/ifcfg-eth0 && cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
ONBOOT=yes
IPADDR=192.168.123.253
NETMASK=255.255.255.0
GATEWAY=192.168.123.1
NM_CONTROLLED=no
DNS1=192.168.123.1
DOMAIN=redhat.local
EOF' || { echoerr "Unable to customise undercloud VM"; return 1; }


  echoinfo "Creating undercloud VM: ${UNDERC_VCPU}vCPUs / ${UNDERC_MEM}MB RAM..."
  virt-install --ram $UNDERC_MEM --vcpus $UNDERC_VCPU --os-variant rhel7 \
    --disk path=${LIBVIRT_D}/images/undercloud.qcow2,device=disk,bus=virtio,format=qcow2 \
    --import --noautoconsole --vnc --network network:provisioning \
    --network network:ospdflt --name undercloud || { echoerr "Unable to create undercloud VM"; return 1; }

  popd

  echoinfo "Enable undercloud VM at hypervisor boot"
  virsh autostart undercloud || { echoerr "Unable to set autostart on undercloud VM"; return 1; }

  echoinfo "Configuring /etc/hosts..."
  echo -e "192.168.123.253\t\tundercloud.redhat.local\tundercloud" >> /etc/hosts

# Remove entry from known_host just in case
  sed -ie '/undercloud/d' ~/.ssh/known_hosts &> /dev/null


  echoinfo "Waiting for undercloud to come up"


  sleep 10

  local nb_tries=0       # Number of SSH connections to try
  local success=0        # Set to 1 if connection worked

  until [ $nb_tries -ge 5 ]
   do

    ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no root@undercloud "uptime" &> /dev/null

    if [ $? -eq 0 ]; then
      echoinfo "Successfully connected to the undercloud"
      success=1
      break
    fi

    nb_tries=$[$nb_tries+1]
    sleep 10

   done

  if [ $success -eq 0 ]; then
    echoerr "Unable to SSH to the undercloud - Has it rebooted properly ?"
    return 1
  fi

  echoinfo "SCP script to undercloud..."
  scp -o StrictHostKeyChecking=no $WHO_I_AM osp-lab.conf root@undercloud:/tmp || { echoerr "Unable to copy $WHO_I_AM to undercloud"; return 1; }
  scp -o StrictHostKeyChecking=no  osp-lab.conf root@undercloud:/tmp || { echoerr "Unable to copy osp-lab.conf to undercloud"; return 1; }
  echo
}


#
#  Define overcloud VMs
#
function define_overcloud_vms()
{

  echoinfo "---===== Create overcloud VMs =====---"

  cd ${LIBVIRT_D}/images/

  for i in $ALL_N;
    do
      echoinfo "Creating disk image for node $i..."
      qemu-img create -f qcow2 -o preallocation=metadata overcloud-$i.qcow2 100G || { echoerr "Unable to define disk overcloud-$i.qcow2"; return 1; }
  done

  for i in $CEPH_N;
    do
        echoinfo "Creating additional disk's image(s) for node $i..."
        for((n=1;n<=$CEPH_OSD_DISK;n+=1)); do
          echoinfo "Creating additional disk $n - ${LIBVIRT_D}/images/overcloud-${i}-storage-${n}.qcow2"
          qemu-img create -f qcow2 -o preallocation=metadata overcloud-${i}-storage-${n}.qcow2 100G || { echoerr "Unable to define disk overcloud-$i-storage-${n}.qcow2"; return 1; }
        done
        echo
  done



  echoinfo "Defining controller nodes..."
  echo

  for i in $CTRL_N;
  do
      echoinfo "Defining node overcloud-$i..."
      virt-install --ram $CTRL_MEM --vcpus $CTRL_VCPU --os-variant rhel7 \
      --disk path=${LIBVIRT_D}/images/overcloud-$i.qcow2,device=disk,bus=virtio,format=qcow2 \
      --noautoconsole --vnc --network network:provisioning \
      --network network:trunk --network network:trunk \
      --name overcloud-$i \
      --cpu host,+vmx \
      --dry-run --print-xml > /tmp/overcloud-$i.xml;

      # Fix for OSP10 + vBMC
      sed -i "/<os>/a\    <bios rebootTimeout='0'\/>" /tmp/overcloud-$i.xml

      virsh define --file /tmp/overcloud-$i.xml || { echoerr "Unable to define overcloud-$i"; return 1; }
  done

  echoinfo "Defining compute nodes..."
  echo

  for i in $COMPT_N;
  do
      echoinfo "Defining node overcloud-$i..."
      virt-install --ram $COMPT_MEM --vcpus $COMPT_VCPU --os-variant rhel7 \
      --disk path=${LIBVIRT_D}/images/overcloud-$i.qcow2,device=disk,bus=virtio,format=qcow2 \
      --noautoconsole --vnc --network network:provisioning \
      --network network:trunk --network network:trunk \
      --name overcloud-$i \
      --cpu host,+vmx \
      --dry-run --print-xml > /tmp/overcloud-$i.xml

      # Fix for OSP10 + vBMC
      sed -i "/<os>/a\    <bios rebootTimeout='0'\/>" /tmp/overcloud-$i.xml

      virsh define --file /tmp/overcloud-$i.xml || { echoerr "Unable to define overcloud-$i"; return 1; }
  done


  echoinfo "Defining ceph nodes..."
  echo

  for i in $CEPH_N;
  do
      echoinfo "Defining node overcloud-$i..."
      virt-install --ram $CEPH_MEM --vcpus $CEPH_VCPU --os-variant rhel7 \
      --disk path=${LIBVIRT_D}/images/overcloud-$i.qcow2,device=disk,bus=virtio,format=qcow2 \
      $(for((n=1;n<=$CEPH_OSD_DISK;n+=1)); do echo -n "--disk path=${LIBVIRT_D}/images/overcloud-$i-storage-${n}.qcow2,device=disk,bus=virtio,format=qcow2 "; done) \
      --noautoconsole --vnc --network network:provisioning \
      --network network:trunk --network network:trunk \
      --name overcloud-$i \
      --cpu host,+vmx \
      --dry-run --print-xml > /tmp/overcloud-$i.xml

      # Fix for OSP10 + vBMC
      sed -i "/<os>/a\    <bios rebootTimeout='0'\/>" /tmp/overcloud-$i.xml

      virsh define --file /tmp/overcloud-$i.xml || { echoerr "Unable to define overcloud-$i"; return 1; }
  done


  echoinfo "Defining custom nodes..."
  echo

  for i in $CUST_N;
  do
      echoinfo "Defining custom node overcloud-$i..."

      virt-install --ram $CUST_MEM --vcpus $CUST_VCPU --os-variant rhel7 \
        --disk path=${LIBVIRT_D}/images/overcloud-$i.qcow2,device=disk,bus=virtio,format=qcow2 \
        --noautoconsole --vnc --network network:provisioning \
        --network network:ospdflt --network network:trunk \
        --name overcloud-$i \
        --cpu host,+vmx \
        --dry-run --print-xml > /tmp/overcloud-$i.xml

        # Fix for OSP10 + vBMC
        sed -i "/<os>/a\    <bios rebootTimeout='0'\/>" /tmp/overcloud-$i.xml

      virsh define --file /tmp/overcloud-$i.xml || { echoerr "Unable to define overcloud-$i..."; return 1; }
  done

  rm -f /tmp/overcloud-*


}

function configure_vbmc()
{

  echoinfo "---===== Configuring Virtual BMC =====---"

 echoinfo "Setting up dummy IPs..."
#  echoinfo "Adding dummy kernel module at system boot"
#  echo dummy > /etc/modules-load.d/dummy.conf
#  echoinfo "Generating config file /etc/sysconfig/network-scripts/ifcfg-dummy0"
#
#  cat << EOF > /etc/sysconfig/network-scripts/ifcfg-dummy0
#DEVICE=dummy0
#ONBOOT=yes
#NM_CONTROLLED="no"
#IPADDR=192.168.125.1
#PREFIX=24
#$(for ((i=2;i<=20;i++)); do
#echo IPADDR${i}=192.168.125.${i}
#echo PREFIX${i}=24
#done)
#EOF
#
#  echoinfo "Loading dummy kernel module"
#  modprobe dummy numdummies=1|| { echoerr "Unable to load dummy kernel module"; return 1; }
#
  echoinfo "Bringing up dummy0 interface"
#  #ifup dummy0 
#  if [ "$?" != 0 ]; then 
#	  rm /etc/sysconfig/network-scripts/ifcfg-dummy0
#	  echoerr "ifcfg failed for dummy0 trying nmcli"
	  nmcli con add ifname dummy0 type dummy con-name dummy0 autoconnect yes
  	  nmcli con mod dummy0 ipv4.addresses  192.168.125.1/24,192.168.125.2/24,192.168.125.3/24,192.168.125.4/24,192.168.125.5/24,192.168.125.6/24,192.168.125.7/24,192.168.125.8/24,192.168.125.9/24,192.168.125.10/24,192.168.125.11/24,192.168.125.12/24,192.168.125.13/24,192.168.125.14/24,192.168.125.15/24,192.168.125.16/24,192.168.125.17/24,192.168.125.18/24,192.168.125.19/24,192.168.125.20/24
	  nmcli con mod dummy0 ipv4.method manual
	  nmcli con up dummy0 
	  if [ "$?" != 0 ]; then
  	    { echoerr "Unable to bring up dummy0 interface"; return 1; }
	  fi
#  fi


  echoinfo "Configure Fire	wall for vBMC..."
  echoinfo "Opening port 6230 - 6249/udp"
  sudo firewall-cmd  --add-port=6230-6249/udp --permanent || { echoerr "Unable to open port 6230/udp..."; return 1; }

  echoinfo "Restarting firewall"
  firewall-cmd --reload || { echoerr "Unable to restart firewalld..."; return 1; }

  echoinfo "Adding nodes to Virtual BMC..."

  port=6230
  IP=1
  for i in $(virsh list --all | awk ' /overcloud/ {print $2}'); do
    echoinfo "Adding node $i to Virtual BMC"
    vbmc add $i --address 192.168.125.$IP --port $port  --username admin --password redhat || { echoerr "Unable to add node $i to Virtual BMC..."; return 1; }

    echoinfo "Starting Virtual BMC service for node $i"
    #systemctl enable --now virtualbmc@${i} || { echoerr "Unable to start Virtual BMC service for $i..."; return 1; }
    vbmc start $i
    sleep 1
    echoinfo "Testing IPMI connection on node $i"
    ipmitool -I lanplus -U admin -P redhat  -H 192.168.125.$IP -p $port  power status || { echoerr "IPMI test on node $i failed..."; return 1; }

    IP=$((IP+1))
  done


  echoinfo "Setting VirtualBMC sudo permissions for stack users"
  echo -e "stack\tALL=(root)\tNOPASSWD:/usr/bin/vbmc" > /etc/sudoers.d/vbmc

}

 

#
#  Summary output
#
function libv_post_install_output()
{

  echo
  echoinfo "---===== SUMMARY =====---"
  echo

  echo "You can connect to the undercloud VM with ssh root@undercloud / p: redhat / IP : 192.168.123.253"
  echo
  echo "Two virtual networks have been set"
  echo "- Default : 192.168.123.0/24 / GW : 192.168.123.1"
  echo "- Provisioning : 172.16.0.0/24 / GW : 172.16.0.254"
  echo
  echo "List your VMs with virsh list --all"

  echo
  echo "Use default network for overcloud traffic - Use eth1 & eth2 for bonding"
  echo
  echoinfo "Next steps :"
  echo "---- ${RED} !!! PLEASE REBOOT YOUR SYSTEM !!! ${NORMAL}----"
  echo "- Optional Run \"osp-lab-deploy.sh idm-deploy\" as root on the hypervisor if you've set DEPLOY_IDM=yes"
  echo "- ssh root@undercloud"
  echo "- run sh /tmp/osp-lab-deploy.sh undercloud-install as root"
  echo
  echo "Happy hacking !!! - The field PM Team"

}

function libvirt_deploy()
{

  echoinfo "Checking UID..."
  if [ $UID -ne 0 ]; then
    echoerr "Please run this script as root"
    exit_on_err
  fi

  install_packages "$PKG_HYPERVISOR" || exit_on_err
  # Install vbmc from python sources
  if ! [ -f /usr/bin/vbmc]; then
  	pip install virtualbmc || exit_on_err
  fi
  check_requirements || exit_on_err
  libv_misc_sys_config || exit_on_err
  define_virt_net || exit_on_err
  define_basic_image || exit_on_err
  define_undercloud_vm || exit_on_err
  define_overcloud_vms || exit_on_err
  if [ "$IRONIC_DRIVER" = "vbmc" ];
    then
    configure_vbmc || exit_on_err
  fi
  libv_post_install_output

}


##########################################################################
#                                                                        #
#                      Undercloud install functions                      #
#                                                                        #
##########################################################################


#
#  Miscellaneous system config
#
function undercloud_misc_sys_config()
{

  echoinfo "---===== Misc System Config =====---"

  echoinfo "Setting Hostname to undercloud.redhat.local"
  hostnamectl set-hostname undercloud.redhat.local || { echoerr "Unable to set hostname undercloud.redhat.local"; return 1; }

# Set undercloud DNS to IPA IP if DEPLOY_IDM="yes"
  if [ $DEPLOY_IDM = "yes" ]; then
  sed -i "/DNS1=/c\DNS1=$IDM_BIND_IP" /etc/sysconfig/network-scripts/ifcfg-eth1 || { echoerr "Unable to set DNS to $IDM_BIND_IP"; return 1; }
  fi

  echoinfo "Restarting network service"
  systemctl  restart network || { echoerr "Unable to restart network service"; return 1; }

  echoinfo "Populating Hosts file"
  ipaddr=$(facter ipaddress_eth1)
  echo -e "$ipaddr\t\tundercloud.redhat.local\tundercloud" >> /etc/hosts

  echoinfo "Creating system user stack..."
  useradd stack

  echoinfo "Setting stack user password to redhat"
  echo "redhat" | passwd stack --stdin

  echoinfo "Creating SSH keypair"
  if [ -e /home/stack/.ssh/id_rsa ]; then
    echoinfo "SSH keypair already exists, skipping..."
  else
    sudo -u stack ssh-keygen -b 2048 -t rsa -f /home/stack/.ssh/id_rsa -q -N ""
  fi

  echoinfo "Adding hypervisor's SSH key to stack user authorized_keys"
  cp /root/.ssh/authorized_keys /home/stack/.ssh/authorized_keys
  chown stack:stack /home/stack/.ssh/authorized_keys

  echoinfo "Adding stack user to sudoers"
  echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
  chmod 0440 /etc/sudoers.d/stack

  echoinfo "Copying stack user SSH key to hypervisor..."
  sudo -u stack sshpass -p 'redhat' ssh-copy-id -o StrictHostKeyChecking=no stack@192.168.123.1 || { echoerr "Unable to copy SSH key to hypervisor - Check password authentication is enabled"; return 1; }

  echoinfo "Testing virsh connection to hypervisor"
  sudo -u stack virsh -c qemu+ssh://stack@192.168.123.1/system list || { echoerr "Unable to connect to the hypervisor"; return 1; }

  echoinfo "Disabling Libvirtd on the undercloud"
  systemctl disable libvirtd

}




function configure_undercloud()
{

  echoinfo "Configuring undercloud.conf"

  sudo -u stack cp /usr/share/instack-undercloud/undercloud.conf.sample /home/stack/undercloud.conf || { echoerr "Failed to copy sample undercloud file to /home/stack/"; return 1; }

  sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT local_ip 172.16.0.1/24
  sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT local_interface eth0
  sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT masquerade_network 172.16.0.0/24

  if [ $OSP_VERSION -le 13 ]; then
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT undercloud_public_vip  172.16.0.10
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT undercloud_admin_vip 172.16.0.11
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT dhcp_start 172.16.0.20
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT dhcp_end 172.16.0.120
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT network_cidr 172.16.0.0/24
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT network_gateway 172.16.0.1
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT discovery_iprange 172.16.0.150,172.16.0.180
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT inspection_iprange 172.16.0.150,172.16.0.180
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT generate_service_certificate false
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT clean_nodes true

# OSP14+ some undercloud.conf parameters change and the undercloud is now containerised
  else
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT undercloud_public_host 172.16.0.10
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT undercloud_admin_host 172.16.0.11
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT clean_nodes true
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT container_images_file /home/stack/undercloud-templates/containers-prepare-parameter.yaml
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT undercloud_ntp_servers clock.redhat.com
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT docker_insecure_registries brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888

    sudo -u stack crudini --set /home/stack/undercloud.conf ctlplane-subnet local_subnet ctlplane-subnet
    sudo -u stack crudini --set /home/stack/undercloud.conf ctlplane-subnet masquerade true
    sudo -u stack crudini --set /home/stack/undercloud.conf ctlplane-subnet cidr 172.16.0.0/24
    sudo -u stack crudini --set /home/stack/undercloud.conf ctlplane-subnet gateway 172.16.0.1
    sudo -u stack crudini --set /home/stack/undercloud.conf ctlplane-subnet inspection_iprange 172.16.0.150,172.16.0.180
    sudo -u stack crudini --set /home/stack/undercloud.conf ctlplane-subnet dhcp_start 172.16.0.20
    sudo -u stack crudini --set /home/stack/undercloud.conf ctlplane-subnet dhcp_end 172.16.0.120

    sudo -u stack mkdir /home/stack/undercloud-templates || { echoerr "Failed to create /home/stack/undercloud-templates directory"; return 1; }

    echoinfo "Generating containers-prepare-parameter.yaml..."
    sudo -u stack openstack tripleo container image prepare default  --local-push-destination  --output-env-file /home/stack/undercloud-templates/containers-prepare-parameter.yaml || \
    { echoerr "Failed to generate /home/stack/undercloud-templates/containers-prepare-parameter.yaml "; return 1; }
# Set container registry to internal one if using rhos-release
    if [ "$SUB_TYPE" = "rhos-release" ]; then
      sudo -u stack sed -i "s?registry.access.redhat.com/rhosp14?brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/rhosp${OSP_VERSION}?" /home/stack/undercloud-templates/containers-prepare-parameter.yaml
    fi
    
  fi

  if [ $DEPLOY_IDM = "yes" ]; then

    echoinfo "Installing novajoin..."
    sudo yum install -y python-novajoin || { echoerr "Failed to install python-novajoin"; return 1; }

    echoinfo "Getting OTP from IDM..."
    otp=$(sudo /usr/libexec/novajoin-ipa-setup \
      --principal admin \
      --password redhat42 \
      --server ipa.redhat.local \
      --realm REDHAT.LOCAL \
      --domain redhat.local \
      --hostname undercloud.redhat.local \
      --precreate)

    if [ $? -eq 0 ]; then
      echoinfo "Successfully retrieved OTP from IDM: $OTP"
    else
      echoerr "Failed to retrieve OTP password from IDM!"
      return 1
    fi

    echoinfo "Configuring IDM parameters in undercloud.conf"
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT enable_novajoin true
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT ipa_otp $otp
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT undercloud_hostname undercloud.redhat.local
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT overcloud_domain_name redhat.local
    sudo -u stack crudini --set /home/stack/undercloud.conf DEFAULT undercloud_nameservers $IDM_BIND_IP
  fi

}



#
#  Summary output
#
function undercloud_post_install_output()
{

  echo
  echoinfo "---===== SUMMARY =====---"
  echo

  echo "Base system and undercloud configuration completed !"
  echoinfo "Next steps :"
  echo "- !!!! REBOOT the undercloud VM !!!!"
  echo "- Check ~stack/undercloud.conf file"
  echo "- Run openstack undercloud install as stack user"
  echo "- Check the undercloud install is successful"
  echo "- Run osp-lab-deploy.sh overcloud-register as stack user"

}


function undercloud_install()
{

  echoinfo "Checking UID..."
  if [ $UID -ne 0 ]; then
    echoerr "Please run this script as root"
    exit_on_err
  fi


  install_packages "$PKG_UNDERCLOUD" || exit_on_err
  undercloud_misc_sys_config || exit_on_err
  configure_undercloud || exit_on_err
  undercloud_post_install_output
  echo "rebooting undercloud in 30 seconds"
  count=30
  while [ $count -gt 0 ]; do
	echo -n ". $count "
	count=$(expr $count - 1)
	sleep 1
  done
  /sbin/reboot
}


##########################################################################
#                                                                        #
#                Undercloud node registration functions                  #
#                                                                        #
##########################################################################



function upload_overcloud_image()
{

  echoinfo "---===== Upload Overcloud images =====---"

  echoinfo "Installing package rhosp-director-images..."
  sudo yum install rhosp-director-images -y || { echoerr "Unable to install package rhosp-director-images"; return 1; }

  echoinfo "Create /home/stack/images directory"
  mkdir -p ~/images/
  cd  ~/images/

  echoinfo "Extracting IPA image to ~/images..."
  tar xvf /usr/share/rhosp-director-images/ironic-python-agent.tar -C . || { echoerr "Unable to extract IPA image"; return 1; }

  echoinfo "Extracting overcloud image to ~/images..."
  tar xvf /usr/share/rhosp-director-images/overcloud-full.tar -C . || { echoerr "Unable to extract overcloud images"; return 1; }

  echoinfo "Customising overcloud image..."
  if ["$SUB_TYPE" == "rhos-release"]; then 
  	  virt-customize -a ~/images/overcloud-full.qcow2 --root-password password:redhat --run-command "rpm -ivh http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm && rhos-release ${RHOS_VERSION}-director" || { echoerr "Unable to customise overcloud image"; return 1; }
  elif ["$SUB_TYPE" == "rhn"]; then 
     virt-customize -a ~/images/overcloud-full.qcow2 --root-password password:redhat || { echoerr "Unable to customise overcloud image"; return 1; }
  fi
  
  echoinfo "Uploading images to glance"
  openstack overcloud image upload || { echoerr "Failed to upload images to glance"; return 1; }
}

#
#  Dynamic instackenv generation for VirtualBMC (nasty bash)
#

function generate_instackenv_vbmc()
{
  echoinfo "Generating ~/instackenv.json file with VirtualBMC (pxe_ipmitool) driver..."

  echoinfo "Retrieving VirtualBMC assignments"
  ssh stack@192.168.123.1 sudo vbmc list | awk ' /overcloud/ {print $2" "$6" "$8}' > /tmp/vbmc_assign

  (
    count=1

    cat << EOF
{
  "nodes": [
EOF

for node in $ALL_N; do

    cat << EOF
    {
      "name": "overcloud-$node",
      "pm_addr": "$(grep overcloud-$node /tmp/vbmc_assign  | cut -d' ' -f2)",
      "pm_password": "redhat",
      "pm_type": "pxe_ipmitool",
      "pm_port": "$(grep overcloud-$node /tmp/vbmc_assign | cut -d' ' -f3)",
      "mac": [
        "$(sed -n ${count}p /tmp/nodes.txt)"
      ],
      "pm_user": "admin"
    },
EOF

  (( count += 1 ))
done

    cat << EOF
  ]
}
EOF
  )>/tmp/instackenv.tmp

# Find the last '},' line so we can remove the ',' - yeah ugly hein :)
# TODO: Find something more elegant
  LINE=$(($(cat /tmp/instackenv.tmp | wc -l) - 2))

# Remove ',' from the last block
  sed -i -e "${LINE}s/,//g" /tmp/instackenv.tmp

  jq . /tmp/instackenv.tmp > ~/instackenv.json

}


#
#  Dynamic instackenv generation for PXE_SSH (nasty bash)
#

function generate_instackenv_ssh()
{

  echoinfo "Generating ~/instackenv.json file with pxe_ssh driver"

  (
    count=1

    cat << EOF
{
  "nodes": [
EOF

for node in $ALL_N; do

    cat << EOF
    {
      "pm_user": "stack",
      "mac": [
        "$(sed -n ${count}p /tmp/nodes.txt)"
      ],
      "pm_type": "pxe_ssh",
      "pm_password": "$(cat ~/.ssh/id_rsa)",
      "pm_addr": "192.168.123.1",
      "name": "overcloud-$node"
    },
EOF

  (( count += 1 ))
done

    cat << EOF
  ]
}
EOF
  )>/tmp/instackenv.tmp

# Find the last '},' line so we can remove the ',' - yeah ugly hein :)
  LINE=$(($(cat /tmp/instackenv.tmp | wc -l) - 2))

# Remove ',' from the last block
  sed -i -e "${LINE}s/,//g" /tmp/instackenv.tmp

  jq . /tmp/instackenv.tmp > ~/instackenv.json

}

#
#  Register overcloud nodes into undercloud's Ironic and introspect nodes
#

function register_overcloud_nodes()
{
  echoinfo "---===== Registering overcloud images =====---"

  cd ~
  echoinfo "Dumping overcloud's nodes provisioning MAC addresses to /tmp/nodes.txt"
  for i in $ALL_N; do
    echoinfo "Looking for node $i"
    virsh -c qemu+ssh://stack@192.168.123.1/system  domiflist overcloud-$i | awk '$3 == "provisioning" {print $5};' || { echoerr "Unable to get MAC address of node $i"; return 1; }
  done > /tmp/nodes.txt


  if [ "$IRONIC_DRIVER" = "vbmc" ];
    then
    generate_instackenv_vbmc
  elif [ "$IRONIC_DRIVER" = "ssh" ];
    then
    generate_instackenv_ssh
  else
    echoerr "Incorrect Ironic Driver selected : $IRONIC_DRIVER ! Accepted values are ssh or vbmc"
    return 1
  fi


  echoinfo "Importing overcloud nodes and introspecting nodes..."
  openstack overcloud node import --provide instackenv.json --introspect --provide --instance-boot-option local ||  { echoerr "Failed to import/instrospect nodes !"; return 1; }

  if [ $DEPLOY_IDM = "yes" ]; then
    local dns=$IDM_BIND_IP
  else
    local dns=192.168.123.1
  fi

  echoinfo "Setting DNS to $dns on Neutron provisioning network..."
  openstack subnet set --dns-nameserver $dns ctlplane-subnet

  echoinfo "Setting brew-pulp-docker01.web.prod.ext.phx2.redhat.com to the list of insecure registries"
  sudo sed -i '/INSECURE_REGISTRY/c\INSECURE_REGISTRY="--insecure-registry 172.16.0.1:8787 --insecure-registry 172.16.0.11:8787 --insecure-registry brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888 --insecure-registry docker-registry.engineering.redhat.com"' /etc/sysconfig/docker
  echoinfo "Restarting docker service"
  sudo systemctl restart docker

}


#
#  Tag overcloud nodes to their respective properties.
#

function tag_overcloud_nodes()
{

  local sched_incr=0

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

  echoinfo "Tagging Custom nodes to $CUST_FLAVOR profile and $CUST_SCHED scheduler hint..."
  sched_incr=0
  for i in $CUST_N; do
    echoinfo "Setting up $i..."
    openstack baremetal node set overcloud-$i --property capabilities=profile:${CUST_FLAVOR},node:${CUST_SCHED}-${sched_incr},${CUST_OTHER_PROP} || { echoerr "Setting Ironic properties on node $i failed !"; return 1; }
    ((sched_incr+=1))
  done


  echoinfo "Creating $CUST_FLAVOR custom flavor..."
  openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 1 $CUST_FLAVOR || { echoerr "Unable to create custom $CUST_FLAVOR flavor !"; return 1; }
  openstack flavor set  --property "capabilities:boot_option"="local" --property "capabilities:profile"=$CUST_FLAVOR $CUST_FLAVOR ||  { echoerr "Unable to configure networker flavor !"; return 1; }

}

# Configure IDM for overcloud LDAP authentication (service + tenant user). Non blocking function, script won't fail it something goes wrong.
function post_idm_config()
{

  echoinfo "---===== IDM post configuration  =====---"

  echoinfo "Authenticating to kerberos server as admin..."
  echo "redhat42" | kinit admin ||  { echoerr "Unable to login as admin!"; return 1; }

  echoinfo "Adding service user svc-ldap..."
  ipa user-add svc-ldap --first OpenStack --last RH
  echoinfo "Setting svc-ldap user password to \"redhat\""
  echo "redhat" | ipa passwd svc-ldap

  echoinfo "Adding group grp-openstack..."
  ipa group-add --desc="OpenStack Users" grp-openstack
  echoinfo "Adding svc-ldap to grp-openstack group..."
  ipa group-add-member --users=svc-ldap grp-openstack

  echoinfo "Adding OpenStack user test-user"
  ipa user-add test-user --first test --last user
  echoinfo "Setting test-user passwd to \"test\""
  echo "test" | ipa passwd test-user
  echoinfo "Adding test-user to grp-openstack group"
  ipa group-add-member --users=test-user grp-openstack

}

function overcloud_reg_post_install_output()
{

  echoinfo "Sucessfully uploaded overcloud image to glance"
  echoinfo "Sucessfully register overcloud nodes to ironic : $ALL_N"
  echoinfo "source ~/stackrc to start playing !!!"
  echo
  echo "Happy hacking !!! - The field PM Team"

}

function overcloud_register()
{

  echoinfo "Checking UID..."
  if [ $USER != "stack" ]; then
    echoerr "Please run this script as stack user"
    exit_on_err
  fi

  if [ -f ~/stackrc ]; then
    source ~/stackrc
  else
    echoerr "Unable to source ~/stackrc - Have you installed the undercloud ???"
    exit_on_err
  fi


  upload_overcloud_image || exit_on_err
  register_overcloud_nodes || exit_on_err
  tag_overcloud_nodes || exit_on_err

  if [ $DEPLOY_IDM = "yes" ]; then
    post_idm_config
  fi

  echoinfo "All set ! You're good to go !"


}

##########################################################################
#                                                                        #
#                              Deploy IDM                                #
#                                                                        #
##########################################################################

function wait_for_container()
{

  local container_name=$1
  local sleep_t=10       # Sleep interval between tries
  local max_tries=120     # Max number of tries
  local nb_tries=0       # Try counter
  local success=0        # Set to 1 connection worked

  echoinfo "Waiting for container to be fully configured (20m timeout)..."
# 5m on a Dell node - 15m on a Cisco node (yay \o/)
  echoinfo "This process takes approximately 5m on a good standing server."

  until [ $nb_tries -ge $max_tries ]
   do

  if ( docker logs $container_name | tail | grep "FreeIPA server configured" &> /dev/null ); then
      # This means container is configured sucessfully
    echoinfo "--- IDM sucessfully configured! ---"
    success=1
    break
  fi

  if ( docker logs $container_name | tail | grep "FreeIPA server configuration failed" &> /dev/null ); then
      # This means container configuration failed
    echoinfo "IDM configuration failed!"
    break
  fi

  nb_tries=$[$nb_tries+1]
  echo "Try number $nb_tries / $max_tries. Waiting ${sleep_t}s more..."
  sleep $sleep_t

  done

  # Check result
  if [ $success -eq 0 ]; then
    return 1
  else
    return 0
  fi
}

function idm_deploy()
{

  echoinfo "---===== Deploy IDM Container =====---"

  if [ $DEPLOY_IDM != "yes" ]; then
    echoinfo "DEPLOY_IDM is set to $DEPLOY_IDM - Skipping deployment!"
    return 0
  fi
  echoinfo "Installing Docker"
  yum install -y docker ||  { echoerr "Failed to install Docker!"; return 1; }

  echoinfo "Starting Docker service"
  sudo systemctl enable --now docker.service  ||  { echoerr "Failed to enable/start docker!"; return 1; }

  echoinfo "Pulling IDM image from $IDM_IMAGE"
  docker pull $IDM_IMAGE ||  { echoerr "Failed to pull IDM image from $IDM_IMAGE!"; return 1; }

  echoinfo "Tagging IDM image"
  docker tag $IDM_IMAGE idm ||  { echoerr "Failed to tag IDM image $IDM_IMAGE!"; return 1; }

  echoinfo "Verifying $IDM_BIND_IP is reachable..."
  ping -c 3 $IDM_BIND_IP || { echoerr "Failed to ping $IDM_BIND_IP!"; return 1; }

  echoinfo "Configuring firewalld..."
  firewall-cmd --permanent --add-port={80/tcp,443/tcp,389/tcp,636/tcp,88/tcp,88/udp,464/tcp,464/udp,53/tcp,53/udp,123/udp} || { echoerr "Failed to configure firewalld!"; return 1; }
  firewall-cmd --permanent --add-service=freeipa-ldap || { echoerr "Failed to configure firewalld"; return 1; }
  echoinfo "Restarting firewalld..."
  firewall-cmd --reload || { echoerr "Failed to restart firewalld"; return 1; }

  echoinfo "Setting up SELinux..."
  setsebool -P container_manage_cgroup 1

  echoinfo "Starting IDM container..."
  docker run -d --restart unless-stopped --net=bridge  -v /var/lib/ipa-data:/data/ipa1/ipa-data \
    -v /var/log:/data/ipa1/ipa-logs -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -h ipa.redhat.local --tmpfs /run --tmpfs /tmp -e IPA_SERVER_IP=$IDM_BIND_IP  \
    -p $IDM_BIND_IP:88:88 -p $IDM_BIND_IP:88:88/udp -p $IDM_BIND_IP:123:123/udp \
    -p $IDM_BIND_IP:389:389 -p $IDM_BIND_IP:443:443 -p $IDM_BIND_IP:464:464 \
    -p $IDM_BIND_IP:464:464/udp -p $IDM_BIND_IP:636:636 -p $IDM_BIND_IP:7389:7389 \
    -p $IDM_BIND_IP:9443:9443 -p $IDM_BIND_IP:9444:9444 -p $IDM_BIND_IP:9445:9445 \
    -p $IDM_BIND_IP:80:80 -p $IDM_BIND_IP:53:53 -p $IDM_BIND_IP:53:53/udp \
    --name idm -it idm --unattended \
      --realm=REDHAT.LOCAL \
      --mkhomedir \
      --ds-password="redhat42" \
      --admin-password="redhat42" \
      --ip-address=$IDM_BIND_IP \
      --hostname ipa.redhat.local \
      --setup-dns \
      --auto-forwarders \
      --auto-reverse || { echoerr "Failed to start IDM container!"; return 1; }

# We need to wait for IDM to be up and running because of DNS (undercloud uses it) and kerberos for novajoin to work properly.
  wait_for_container idm || { echoerr "IDM container configuration failed! For additional info do a \"docker logs idm\""; return 1; }

# We need to restart docker for obscure reasons, otherwise overcloud nodes cannot reach container.
  echoinfo "Restarting docker service..."
  systemctl restart docker

  echoinfo "Next steps :"
  echo "- ssh root@undercloud"
  echo "- run sh /tmp/osp-lab-deploy.sh undercloud-install as root"
  echo
  echo "Happy hacking !!! - The field PM Team"

}

##########################################################################
#                                                                        #
#                             Main function                              #
#                                                                        #
##########################################################################


case $1 in
  "uc-redeploy")
    echoinfo "Starting undercloud redeploy"
    echo "Ready to destroy and dedeploy the undercloud?"
    read junk
    virsh destroy undercloud
    virsh undefine undercloud
    rm -f ${LIBVIRT_D}/images/undercloud.qcow2
    define_undercloud_vm
  ;;
  "libvirt-deploy")
    echoinfo "Starting libvirt deployment..."
    libvirt_deploy
   ;;
  "idm-deploy")
    echoinfo "Starting IDM container deployment..."
    idm_deploy || exit_on_err
  ;;
  "undercloud-install")
    echoinfo "Starting undercloud installation..."
    undercloud_install
  ;;
  "overcloud-register")
    echoinfo "Starting undercloud nodes registration..."
    overcloud_register
  ;;
  "howto")
    howto
  ;;
*)
  echoerr "Invalid argument"
  help
  ;;
esac
