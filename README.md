# SecurityOnion-ISO-Customization and Ansible Deployment
This is a fork from ThreatHunterNotebook's Security Onion ISO Customization. I have much appreciation for what ThreatHunterNotebooks has created and I wouldn't have able to create this without the help of his GitHub. Part of this repository is meant to be an update and to fix many of the issues I ran into while utilizing ThreatHunterNotebooks's Security Onion ISO customization and ansible deployment.

Security Onion ISO Customization Process
This repository is an update, as well as an introduction of automation for creating automated Security Onion ISO's by the use of kickstart scritps and Security Onions built in automation processes.
## System Prep
The first step to creating a custom SO ISO is to download the ISO to a system that can create an ISO.  In this case, we use either a Ubuntu system or CentOS system.
The current version of SO is 2.3.140.
On a Ubuntu system ensure the following packages are installed:
<pre><code>sudo apt install isohybrid
sudo apt install syslinux-utils
sudo apt install isolinux
sudo apt install ansible
</code></pre>
On a CentOS system ensure the following packages are installed:
<pre><code>
sudo yum install mkisofs
sudo yum install syslinux
sudo yum install epel-release
sudo yum install ansible
</code></pre>
Both will need the SMCIPMITool unzipped in its own SMCIPMITool directory. This tools is a commandline method that can be used to automate installs of ISO's on servers with IPMI interfaces.
<pre><code>
https://www.supermicro.com/en/support/resources/downloadcenter/smsdownload
</code></pre>
Copy the Security Onion 2.3.x ISO to your Linux platform.
Mount the ISO.
Create a directory to which you will copy the ISO files.
Here we are only copying specific files that we need for the automation of the security onion ISO.
<pre><code>sudo mount -o loop securityonion-2.3.61.iso /mnt
sudo mkdir /tmp/seconion
sudo cp /mnt/isolinux.cfg /tmp/seconion/
sudo cp /mnt/ks.cfg /tmp/seconion/
sudo cp /mnt/SecurityOnion/setup/automation/distributed-airgap-* /tmp/seconion
cd /tmp/seconion
</code></pre>
###############################################################################################################

We are primarily concerned with four files: isolinux.cfg, ks.cfg, so-functions and the distributed-airgap files
### isolinux.cfg configurations
The isolinux.cfg file is the boot menu that allows the user to select how they want to boot the system. Since most methods of installing security utilize a mounted cdrom (ESXI, IPMI) we need to change isolinux.cfg to reflect this.

Change the following
<pre><code>
label linux
  menu label ^Install Security Onion 2.3.61
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 ks=file:///ks.cfg quiet

label linux
  menu label ^Install Security Onion 2.3.61 in basic graphics mode
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 ks=file:///ks.cfg nomodeset quiet

label check
  menu label Test this ^media & install Security Onion 2.3.61
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check ks=file:///ks.cfg quiet
</code></pre>
Changes to make are lines related to the *ks* option.  Basically changing **ks=file:///ks.cfg** to **ks=cdrom:/ks.cfg**.
<pre><code>
label linux
  menu label ^Install Security Onion 2.3.61
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 ks=cdrom:/ks.cfg

label linux
  menu label ^Install Security Onion 2.3.61 in basic graphics mode
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 ks=cdrom:/ks.cfg nomodeset

label check
  menu label Test this ^media & install Security Onion 2.3.61
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check ks=cdrom:/ks.cfg
</code></pre>
The SO install also has a boot message that waits for the user to press ENTER before continuing.  We want to comment out that line in the isolinux.cfg file, also.
<pre><code>
#display boot.msg
</code></pre>
############################################################################################
Save the file.  Next we want to customize the kickstart script.
</code></pre>
Before we discuss changing the kickstart script, let's discuss our goals
1. Since we are using Ansible to install automatically when utilizing a mounted cdrom, we need to add a line to ensure our network interfaces assign proper ip addressing so we do not need to rely on dhcp or reservations.
2. We want the SO install to be automatic with no user intervention.
3. We want to  make sure a preliminary username and password is implemented so the Ansible playbooks can make the necessary SSH communications.
4. We want to set the SecurityOnion tools directory to executable to ensure the automated install process has the correct permissions.
5. Automate the process using ansible so we can create iso's for various situations.



Below is an example of the customized ks.cfg file. 
NOTE: Interfaces will change depending on the environment. ens192 is typically the first interface to populate in an ESXI environment. ens33 is the first to populate in a VMWare Workstation environment. It will take some testing to get it correct for your environment.
<pre><code>
# Set the firewall to allow SSH
firewall --enabled --port=22:tcp

# Install Mode
install

# Lock the root account
rootpw --lock

# Force this to use the shadow file
auth --useshadow --passalgo=sha512

# Install via Text Mode
text

# Disable firstboot. We don't have a GUI
firstboot --disable

# Set the keyboard
keyboard us

# Set the language
lang en_US

# Network information
network  --bootproto=static --ip={{ SOManager.IP }} --netmask={{ SOManager.Subnet }} --gateway={{ SOManager.Gateway }} --device=ens33 --onboot=on --activate

# Turn on SELinux
selinux --enforcing

# No X Windows please
skipx

# Installation logging level
logging --level=info

# Reboot after install
reboot --eject

# System timezone to UTC
timezone --isUtc Etc/UTC

#%include /tmp/uefi
%include /tmp/part-include

%pre

#!/bin/sh
exec < /dev/tty6 > /dev/tty6

# Switch to the tty so we can type stuff
chvt 6

# Get the megarams
mem=$(($(free -m | grep Mem | awk '{print $2}')+2000))

# Set drives to 0 for now
NUMDRIVES=0

# Block device directory
DIR="/sys/block"

# Minimum drive size in GIGABYTES
MINSIZE=99

# Set the root drive to blank for now
ROOTDRIVE=""

if [ -d /sys/firmware/efi ]; then
  is_uefi=true
fi

TEMPDRIVE=/tmp/part-include

# Ask some basic questions

for DEV in sda sdb sdc sdd hda hdb hdc hdd vda vdb vdc vdd nvme0n1 nvme1n1 nvme2n1 nvme3n1 xvda xvdb xvdc xvdd ; do
  if [ -d $DIR/$DEV ]; then

    # Find removeable devices so we don't install on them
    REMOVABLE=$(cat $DIR/$DEV/removable)

    if (( $REMOVABLE == 0 )); then
      NUMDRIVES=$((NUMDRIVES+1))
      SIZE=$(cat $DIR/$DEV/size)
      GB=$(($SIZE/2**21))
    fi
  fi
done

# If there is a single drive move forward
if [ $NUMDRIVES -lt 2 ]; then
  for DEV in sda sdb sdc sdd hda hdb hdc hdd vda vdb vdc vdd nvme0n1 nvme1n1 nvme2n1 nvme3n1 xvda xvdb xvdc xvdd ; do
    if [ -d $DIR/$DEV ]; then
      REMOVABLE=$(cat $DIR/$DEV/removable)
      if (( $REMOVABLE == 0 )); then
        SIZE=$(cat $DIR/$DEV/size)
        GB=$(($SIZE/2**21))
        if [ $GB -gt $MINSIZE ]; then
          ROOTDRIVE=$DEV
        else
          echo "Not enough space to install Security Onion. You need at least $MINSIZE GB to proceed"
          read drivetoosmall
        fi
      fi
    fi
  done

  ROOTSIZE=$(($GB/3))

  # Set the volume size to 300GB if it's larger than 300GB
  if [ $ROOTSIZE -gt 300 ]; then
    ROOTPART=300
  else
  # If there isn't at least 300GB set it to what is there.
    ROOTPART=$ROOTSIZE
  fi

# Determine if we need to use gpt
#  if [ $GB -gt 1 ]; then
    parted -s /dev/$ROOTDRIVE mklabel gpt
#  fi
  echo 'zerombr' > $TEMPDRIVE
  echo -e "clearpart --all --drives=$ROOTDRIVE --initlabel" >> $TEMPDRIVE
  if [ ! $is_uefi ]; then
  echo -e "bootloader --location=mbr --driveorder=$ROOTDRIVE" >> $TEMPDRIVE
  echo -e "part biosboot --fstype=biosboot --size=1 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
  echo -e "part /boot --asprimary --fstype=xfs --size=500 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
  fi
  if [ $is_uefi ]; then
  echo -e "part /boot/efi --asprimary --fstype="fat32" --size=1024 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
  echo -e "part /boot --fstype=xfs --size=500 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
  fi
  echo -e "part pv.1 --size 1 --grow --fstype=xfs --ondrive=$ROOTDRIVE" >> $TEMPDRIVE
  echo -e "volgroup system pv.1" >> $TEMPDRIVE
  echo -e "logvol swap --vgname system --size=8192 --name=swap" >> $TEMPDRIVE
  echo -e "logvol /tmp --fstype xfs --vgname system --size=2000 --name=tmp --fsoptions=\"nodev,nosuid,noexec\"" >> $TEMPDRIVE
  echo -e "logvol / --fstype xfs --vgname system --size=$(($ROOTPART*1000)) --name=root" >> $TEMPDRIVE
  echo -e "logvol /nsm --fstype xfs --vgname system --grow --size=1 --name=nsm" >> $TEMPDRIVE

else
  echo "Multiple drives detected.  Let's answer some questions."

  #If there's more than one drive we need to make some choices
  NUMDRIVES=0
  while [ -z $ROOTDRIVE ]
  do
    echo -e "Device\tSize"
    for DEV in sda sdb sdc sdd hda hdb hdc hdd vda vdb vdc vdd nvme0n1 nvme1n1 nvme2n1 nvme3n1 xvda xvdb xvdc xvdd; do
      if [ -d $DIR/$DEV ]; then
        REMOVABLE=$(cat $DIR/$DEV/removable)
        if (( $REMOVABLE == 0 )); then
          NUMDRIVES=$((NUMDRIVES+1))
          SIZE=$(cat $DIR/$DEV/size)
          GB=$(($SIZE/2**21))
          echo -e "$DEV\t$(($SIZE/2**21))GB"
        fi
      fi
    done

  echo "There are $NUMDRIVES available disk(s)"

    echo "Which device would you like to use as the operating system filesystem (must be larger than $MINSIZE GB):"
    read rootchoice
    if [ -d $DIR/$rootchoice ]; then
      REMOVABLE=$(cat $DIR/$rootchoice/removable)
      if (( $REMOVABLE == 0 )); then
        SIZE=$(cat $DIR/$rootchoice/size)
        GB=$(($SIZE/2**21))
        if [ $GB -gt $MINSIZE ]; then
          echo -e "$rootchoice\t$(($SIZE/2**21))GB - OS Drive"
          ROOTDRIVE=$rootchoice
        else
          echo "Available volume does not meet size requirements.  Please provide a volume greater than $MINSIZE GB"
          NUMDRIVES=0
        fi
      else
        echo "That is a removable drive. Please provide a device name for a fixed disk"
        NUMDRIVES=0
      fi
    else
      echo "That device does not exist.  Please pick one of the above listed devices"
      NUMDRIVES=0
    fi
  done
  SAMEDRIVE=""
  NSMDRIVE=""
  while [ -z $SAMEDRIVE ]
  do
    echo "Would you like to use the same device for NSM storage? (yes/no)"
    read SAMEDRIVE
    if [ "$SAMEDRIVE" == "yes" ]; then
      NSMDRIVE=$ROOTDRIVE
      echo -e "$rootchoice\t$(($SIZE/2**21))GB - NSM Drive"
    elif [ "$SAMEDRIVE" == "no" ]; then
      NUMDRIVES=0
      while [ -z $NSMDRIVE ]
      do
        echo -e "Device\tSize"
        for DEV in sda sdb sdc sdd hda hdb hdc hdd vda vdb vdc vdd nvme0n1 nvme1n1 nvme2n1 nvme3n1 xvda xvdb xvdc xvdd ; do
          if [ -d $DIR/$DEV ]; then
            REMOVABLE=$(cat $DIR/$DEV/removable)
            if (( $REMOVABLE == 0 )); then
              NUMDRIVES=$((NUMDRIVES+1))
              SIZE=$(cat $DIR/$DEV/size)
              GB=$(($SIZE/2**21))
              if [ "$DEV" != "$ROOTDRIVE" ]; then
                echo -e "$DEV\t$(($SIZE/2**21))GB"
              fi
            fi
          fi
        done
        echo "Which device would you like to use for NSM storage:"
        read whichnsm
        if [ -d $DIR/$whichnsm ]; then
          REMOVABLE=$(cat $DIR/$whichnsm/removable)
          if (( $REMOVABLE == 0 )); then
            echo -e "$whichnsm\t$(($SIZE/2**21))GB - NSM Drive"
            NSMDRIVE=$whichnsm
            PCAPSIZE=$(cat $DIR/$NSMDRIVE/size)
            PCAPGB=$(($PCAPSIZE/2**21))
          else
            echo "That is a removable drive. Please provide a device name for a fixed disk"
            NUMDRIVES=0
          fi
        else
          echo "That device does not exist.  Please pick one of the above listed devices"
          NUMDRIVES=0
        fi
      done
    else
      SAMEDRIVE=""
    fi
  done
  ROOTRAWSIZE=$(cat $DIR/$ROOTDRIVE/size)
  ROOTGB=$(($ROOTRAWSIZE/2**21))
  if [ "$ROOTDRIVE" == "$NSMDRIVE" ]; then
    ROOTSIZE=$(($ROOTGB/3))
    if [ $ROOTSIZE -gt 300 ]; then
      ROOTPART=300
    else
      ROOTPART=$ROOTSIZE
    fi
  else
    ROOTPART=$ROOTGB
  fi
#  if [ $ROOTGB -gt 1900 ]; then
    parted -s /dev/$ROOTDRIVE mklabel gpt
#  fi
  echo 'zerombr' > $TEMPDRIVE
  if [ "$ROOTDRIVE" == "$NSMDRIVE" ]; then
    echo -e "clearpart --all --drives=$ROOTDRIVE" >> $TEMPDRIVE
  else
    echo -e "clearpart --all --drives=$ROOTDRIVE,$NSMDRIVE --initlabel" >> $TEMPDRIVE
  fi
  if [ "$ROOTDRIVE" == "$NSMDRIVE" ]; then
    if [ ! $is_uefi ]; then
      echo -e "bootloader --location=mbr --driveorder=$ROOTDRIVE" >> $TEMPDRIVE
      echo -e "part biosboot --fstype=biosboot --size=1" >> $TEMPDRIVE
      echo -e "part /boot --asprimary --fstype=xfs --size=500 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
    else
      echo -e "part /boot/efi --fstype="fat32" --size=1024 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
      echo -e "part /boot --fstype=xfs --size=500 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
    fi
  else
    if [ ! $is_uefi ]; then
      echo -e "bootloader --location=mbr --driveorder=$ROOTDRIVE,$NSMDRIVE" >> $TEMPDRIVE
      echo -e "part biosboot --fstype=biosboot --size=1" >> $TEMPDRIVE
      echo -e "part /boot --asprimary --fstype=ext4 --size=500 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
    else
      echo -e "part /boot/efi --fstype="fat32" --size=1024 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
      echo -e "part /boot --fstype=ext4 --size=500 --ondisk=$ROOTDRIVE" >> $TEMPDRIVE
    fi
  fi
  echo -e "part pv.1 --size 1 --grow --fstype=xfs --ondrive=$ROOTDRIVE" >> $TEMPDRIVE
  echo -e "volgroup system pv.1" >> $TEMPDRIVE
  if [ "$ROOTDRIVE" == "$NSMDRIVE" ]; then
    echo -e "logvol / --fstype xfs --vgname system --size=$(($ROOTPART*1000)) --name=root" >> $TEMPDRIVE
    echo -e "logvol /nsm --fstype xfs --vgname system --grow --size=1 --name=nsm" >> $TEMPDRIVE
  else
#    if [ $PCAPGB -gt 1900 ]; then
      parted -s /dev/$NSMDRIVE mklabel gpt
#    fi
    echo -e "part pv.2 --size 1 --grow --fstype=xfs --ondrive=$NSMDRIVE" >> $TEMPDRIVE
    echo -e "volgroup nsm pv.2" >> $TEMPDRIVE
    echo -e "logvol /nsm --fstype xfs --vgname nsm --grow --size=1 --name=nsm" >> $TEMPDRIVE
    echo -e "logvol / --fstype xfs --vgname system --grow --size=1 --name=root" >> $TEMPDRIVE
  fi
fi

manufacturer=$(dmidecode -s system-manufacturer)
family=$(dmidecode -s system-family)
product=$(dmidecode -s system-product-name)

INSTALL=no
PWMATCH=no

if [[ "$manufacturer" == "Security Onion Solutions" && "$family" == "Automated" ]]; then
  INSTALL=yes
  PWMATCH=yes
  SOUSER=onion
  echo "PRODUCT=$product" >> /tmp/variables.txt
  echo "SOUSER=$SOUSER" >> /tmp/variables.txt
  echo "PASSWORD=automation" >> /tmp/variables.txt
fi

SOUSER="MYUSERNAME"
PASSWORD1="MYPASSWORD"
PASSWORD2="MYPASSWORD"
  if [ $PASSWORD1 == $PASSWORD2 ]; then
    echo PASSWORD=$PASSWORD1 >> /tmp/variables.txt
    echo SOUSER=$SOUSER >> /tmp/variables.txt
    PWMATCH=yes
  else
    echo "Passwords don't match. Press enter to try again. "
    read -p
  fi
#done 
exec < /dev/tty1 > /dev/tty1
chvt 1
%end

%post --nochroot
cp /tmp/variables.txt /mnt/sysimage/tmp/variables.txt
mkdir /mnt/sysimage/root/SecurityOnion
mkdir -p /mnt/sysimage/nsm/docker-registry/docker
mkdir -p /mnt/sysimage/nsm/repo
rsync -avh --exclude 'TRANS.TBL' /run/install/repo/SecurityOnion/* /mnt/sysimage/root/SecurityOnion/
rsync -avh --exclude 'TRANS.TBL' /run/install/repo/docker/* /mnt/sysimage/nsm/docker-registry/docker/
rsync -avh --exclude 'TRANS.TBL' /run/install/repo/Packages/* /mnt/sysimage/nsm/repo/
chmod +x /mnt/sysimage/root/SecurityOnion/setup/so-setup

%end

%post
source /tmp/variables.txt
rm -f /tmp/variables.txt

useradd $SOUSER
cp -Rvp /root/SecurityOnion /home/$SOUSER/
chown -R $SOUSER:$SOUSER /home/$SOUSER/SecurityOnion/
chmod +x /home/$SOUSER/SecurityOnion/so-setup
chmod -R +x /home/$SOUSER/SecurityOnion/salt/common/tools/sbin/
echo $SOUSER:$PASSWORD | chpasswd --crypt-method=SHA512
echo "$SOUSER   ALL=(ALL)       ALL" >> /etc/sudoers
echo "$SOUSER   ALL=(ALL) NOPASSWD: /home/$SOUSER/SecurityOnion/setup/so-setup" >> /etc/sudoers
#echo "sudo /home/$SOUSER/SecurityOnion/setup/so-setup iso" >> /home/$SOUSER/.bash_profile

if [ ! -z $PASSWORD ]; then
  echo $SOUSER:$PASSWORD | chpasswd --crypt-method=SHA512
fi

#if [ ! -z $PRODUCT ]; then
#  echo "@reboot sudo /home/$SOUSER/SecurityOnion/setup/so-setup iso $PRODUCT" | crontab -u $SOUSER -
#fi

# fix onboot line so interface will come up.
sed -i 's/ONBOOT=no/ONBOOT=yes/g' /etc/sysconfig/network-scripts/ifcfg-ens192


# SSHD Banner
touch /etc/ssh/sshd-banner
echo "##########################################" > /etc/ssh/sshd-banner
echo "##########################################" >> /etc/ssh/sshd-banner
echo "###                                    ###" >> /etc/ssh/sshd-banner
echo "###   UNAUTHORIZED ACCESS PROHIBITED   ###" >> /etc/ssh/sshd-banner
echo "###                                    ###" >> /etc/ssh/sshd-banner
echo "##########################################" >> /etc/ssh/sshd-banner
echo "##########################################" >> /etc/ssh/sshd-banner

# Set the SSHD banner
echo "Banner /etc/ssh/sshd-banner" >> /etc/ssh/sshd_config

if [ -z $PRODUCT ]; then
  exec < /dev/tty6 > /dev/tty6
  chvt 6
  clear
  exec < /dev/tty1 > /dev/tty1
  chvt 1
fi
%end

%packages --nobase
@core
%end
</code></pre>
Save the ks.cfg file once customization is complete

Next we are manipulating the automation files within security onion.
Here is an example of the distributed-airgap-manager file:
<pre><code>
#!/bin/bash

# Copyright 2014-2022 Security Onion Solutions, LLC

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

TESTING=true

address_type=DHCP
ADMINUSER=onionuser
ADMINPASS1=onionuser
ADMINPASS2=onionuser
ALLOW_CIDR=0.0.0.0/0
ALLOW_ROLE=a
BASICZEEK=2
BASICSURI=2
# BLOGS=
#BNICS=eth1
ZEEKVERSION=ZEEK
# CURCLOSEDAYS=
# EVALADVANCED=BASIC
GRAFANA=1
# HELIXAPIKEY=
HNMANAGER=10.0.0.0/8,192.168.0.0/16,172.16.0.0/12
HNSENSOR=inherit
HOSTNAME=Distributed-manager
install_type=MANAGER
INTERWEBS=AIRGAP
# LSINPUTBATCHCOUNT=
# LSINPUTTHREADS=
# LSPIPELINEBATCH=
# LSPIPELINEWORKERS=
MANAGERADV=BASIC
# MDNS=
# MGATEWAY=
# MIP=
# MMASK=
MNIC=eth0
# MSEARCH=
# MSRV=
# MTU=
NIDS=Suricata
# NODE_ES_HEAP_SIZE=
# NODE_LS_HEAP_SIZE=
NODESETUP=NODEBASIC
NSMSETUP=BASIC
NODEUPDATES=MANAGER
# OINKCODE=
OSQUERY=1
# PATCHSCHEDULEDAYS=
# PATCHSCHEDULEHOURS=
PATCHSCHEDULENAME=auto
PLAYBOOK=1
# REDIRECTHOST=
REDIRECTINFO=IP
RULESETUP=ETOPEN
# SHARDCOUNT=
# SKIP_REBOOT=
SOREMOTEPASS1=onionuser
SOREMOTEPASS2=onionuser
STRELKA=1
THEHIVE=0
WAZUH=1
WEBUSER=onionuser@somewhere.invalid
WEBPASSWD1=0n10nus3r
WEBPASSWD2=0n10nus3r
</code></pre>
Next we need to change part of the so-functions file. During the automated installation the detect_cloud() function will hang on the curl if it is not removed.
<pre><code>
detect_cloud() {
  echo "Testing if setup is running on a cloud instance..." | tee -a "$setup_log"
  if ( curl --fail -s -m 5 http://169.254.169.254/latest/meta-data/instance-id > /dev/null ) || ( dmidecode -s bios-vendor | grep -q Google > /dev/null) || [ -f /var/log/waagent.log ]; then export is_cloud="true"; fi
}
</code></pre>
Change to
<pre><code>
detect_cloud() {
  echo "Testing if setup is running on a cloud instance..." | tee -a "$setup_log"
  if ( dmidecode -s bios-vendor | grep -q Google > /dev/null) || [ -f /var/log/waagent.log ]; then export is_cloud="true"; fi
}
</code></pre>
We are going to change the file to hold ansible variables that will reflect in our secrets.yaml file.
Note: This is the general process that will be needed for the distributed-airgap-search and the distributed-airgap-sensor fiels as well.
It should look something like this. 

<pre><code>
#!/bin/bash

# Copyright 2014-2022 Security Onion Solutions, LLC

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

TESTING=false

address_type=static
ADMINUSER={{ SOManager.Username }}
ADMINPASS1={{ SOManager.Pass }}
ADMINPASS2={{ SOManager.Pass }}
ALLOW_CIDR={{ SOManager.Allow }}
ALLOW_ROLE=a
BASICZEEK=2
BASICSURI=2
# BLOGS=
#BNICS=eth1
ZEEKVERSION=ZEEK
# CURCLOSEDAYS=
# EVALADVANCED=BASIC
GRAFANA=1
# HELIXAPIKEY=
HNMANAGER={{ SOManager.Homenet }}
HNSENSOR=inherit
HOSTNAME={{ SOManager.Hostname }}
install_type=MANAGER
INTERWEBS=AIRGAP
# LSINPUTBATCHCOUNT=
# LSINPUTTHREADS=
# LSPIPELINEBATCH=
# LSPIPELINEWORKERS=
MANAGERADV=BASIC
# MDNS=
# MGATEWAY=
# MIP=
# MMASK=
MNIC=eth0
# MSEARCH=
# MSRV=
# MTU=
NIDS=Suricata
# NODE_ES_HEAP_SIZE=
# NODE_LS_HEAP_SIZE=
NODESETUP=NODEBASIC
NSMSETUP=BASIC
NODEUPDATES=MANAGER
# OINKCODE=
OSQUERY=1
# PATCHSCHEDULEDAYS=
# PATCHSCHEDULEHOURS=
PATCHSCHEDULENAME=auto
PLAYBOOK=1
# REDIRECTHOST=
REDIRECTINFO=IP
RULESETUP=ETOPEN
# SHARDCOUNT=
# SKIP_REBOOT=
SOREMOTEPASS1={{ SOManager.Pass }}
SOREMOTEPASS2={{ SOManager.Pass }}
STRELKA=1
THEHIVE=0
WAZUH=1
WEBUSER={{ SOManager.FQDN }}
WEBPASSWD1={{ SOManager.Pass }}
WEBPASSWD2={{ SOManager.Pass }}
</code></pre>
## Compile the Custom ISO
From our custom ISO directory, we want to compile the new ISO. As a side note. "CentOS 7 x86_64" MUST MATCH THE ISOLINUX.CFG FILE OR ELSE IT WILL NOT WORK. 
<pre><code>
mkisofs -o securityonionCustom-2.3.61.iso -allow-limited-size -b isolinux.bin -J -R -l -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -graft-points -joliet-long -R -V "CentOS 7 x86_64" .
</code></pre>

<pre><code>
isohybrid --uefi securityonionCustom-2.3.61.iso
chmod 777 securityonionCustom-2.3.61.iso
</code></pre>

Moving on to automation. Run the following playbooks in order. 
The following playbooks are meant to deploy 1 physical sensors and 1 ESXI instance of SOManager and 1 ESXI instance of SOSearch. 
This setup deploys the Manager and Search nodes before the sensors to ensure proper execution of each of the nodes. 
<pre><code>
ansible-playbook playbooks/deploy.yaml
ansible-playbook playbooks/isogen.yaml
ansible-playbook playbooks/SO_Mamager_Search_Deploy.yaml
ansible-playbook playbooks/SO_MGR_Config.yaml
ansible-playbook playbooks/SO_MGR_setup.yaml
ansible-playbook playbooks/SO_Search_config.yaml
ansible-playbook playbooks/SO_Search_setup.yaml
ansible-playbook playbooks/SO_hard_install.yaml
ansible-playbook playbooks/SO_Sensor_config.yaml
ansible-playbook playbooks/SO_Sensor_setup.yaml
ansible-playbook playbooks/SO_ruleupdate_MGR.yaml

</code></pre>
You can also use the super simple BASH script to run everything. 
<pre><code>
deploy.sh
</code></pre>
