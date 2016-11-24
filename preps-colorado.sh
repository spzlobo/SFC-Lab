#!/bin/bash

echo -e "LANG=en_US.utf8\nLC_ALL=en_US.UTF-8\nLC_CTYPE=en_US.UTF-8" >> /etc/environment
source /etc/environment

echo "Grab a coffee"
echo "Downloading RPMs for Colorado"
curl -sLo /tmp/python3-ipmi.noarch.rpm http://artifacts.opnfv.org/apex/dependencies/python3-ipmi-0.3.0-1.noarch.rpm &
curl -sLo /tmp/python3-jinja2.noarch.rpm http://artifacts.opnfv.org/apex/dependencies/python3-jinja2-2.8-5.el7.centos.noarch.rpm &
curl -sLo /tmp/python-markupsafe34.centos.src.rpm http://artifacts.opnfv.org/apex/dependencies/python34-markupsafe-0.23-9.el7.centos.x86_64.rpm &

curl -sLo /tmp/opnfv-apex-opendaylight-sfc.noarch.rpm http://artifacts.opnfv.org/apex/colorado/opnfv-apex-opendaylight-sfc-3.0--colorado-1.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-common.noarch.rpm  http://artifacts.opnfv.org/apex/colorado/opnfv-apex-undercloud-3.0-colorado-1.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-undercloud.noarch.rpm http://artifacts.opnfv.org/apex/colorado/opnfv-apex-common-colorado-1.0.noarch.rpm &

echo "Install all packages"
YUM_OPTS="-y -d 0 -e 0"
yum ${YUM_OPTS} update
yum ${YUM_OPTS} install epel-release qemu-kvm qemu-img virt-manager libvirt libvirt-python libvirt-client virt-install virt-viewer
yum ${YUM_OPTS} install python34
curl -sL https://bootstrap.pypa.io/get-pip.py | python3.4
yum ${YUM_OPTS} groupinstall "Virtualization Host" chkconfig libvirtd on
yum ${YUM_OPTS} install https://www.rdoproject.org/repos/rdo-release.rpm
yum ${YUM_OPTS} update

echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
modprobe -r kvm_intel
modprobe kvm_intel

echo $(cat /sys/module/kvm_intel/parameters/nested)
echo "Finished - Please rebooting in 10s"

sleep 10
if [ $(ps -aux | grep curl | wc -l) -le 1 ];then reboot; fi
