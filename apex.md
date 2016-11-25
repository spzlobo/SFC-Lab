# OPNFV SFC with Apex

## TODO

- Create automated setup with Ansible

## Source

Initial idea: <https://github.com/trozet/sfc-random>

## Prerequisites

- CentOS 7 (16GB, 40GB HDD)

```bash
echo -e "LANG=en_US.utf8\nLC_ALL=en_US.UTF-8\nLC_CTYPE=en_US.UTF-8" >> /etc/environment
source /etc/environment
```

## Binaries

### Dependencies

```bash
curl -sLo /tmp/python3-ipmi.noarch.rpm http://artifacts.opnfv.org/apex/dependencies/python3-ipmi-0.3.0-1.noarch.rpm &
curl -sLo /tmp/python3-jinja2.noarch.rpm http://artifacts.opnfv.org/apex/dependencies/python3-jinja2-2.8-5.el7.centos.noarch.rpm &
curl -sLo /tmp/python-markupsafe34.centos.src.rpm http://artifacts.opnfv.org/apex/dependencies/python34-markupsafe-0.23-9.el7.centos.x86_64.rpm &
```

### Colorado

```bash
curl -sLo /tmp/opnfv-apex-opendaylight-sfc.noarch.rpm http://artifacts.opnfv.org/apex/colorado/opnfv-apex-opendaylight-sfc-3.0--colorado-1.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-common.noarch.rpm  http://artifacts.opnfv.org/apex/colorado/opnfv-apex-undercloud-3.0-colorado-1.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-undercloud.noarch.rpm http://artifacts.opnfv.org/apex/colorado/opnfv-apex-common-colorado-1.0.noarch.rpm &
```

## Installation

```bash
YUM_OPTS="-y -d 0 -e 0"
yum ${YUM_OPTS} update
yum ${YUM_OPTS} install epel-release qemu-kvm qemu-img virt-manager libvirt libvirt-python libvirt-client virt-install virt-viewer
yum ${YUM_OPTS} install python34
curl -sL https://bootstrap.pypa.io/get-pip.py | python3.4
yum ${YUM_OPTS} groupinstall "Virtualization Host" chkconfig libvirtd on
yum ${YUM_OPTS} install https://www.rdoproject.org/repos/rdo-release.rpm
yum ${YUM_OPTS} update
if [ $(ps -aux | grep curl | wc -l) -le 1 ];then reboot; fi

yum -y install /tmp/*.rpm
```

## Nested virt.

```bash
echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
modprobe -r kvm_intel
modprobe kvm_intel
systemctl restart libvirtd
```

Validation

```bash
$ cat /sys/module/kvm_intel/parameters/nested
Y

$ modinfo kvm_intel | grep nested
parm:           nested:bool
```

## OPNFV deploy

```bash
opnfv-deploy -v -d /etc/opnfv-apex/os-odl_l2-sfc-noha.yaml -n /etc/opnfv-apex/network_settings.yaml
```

Crap a coffee :D If something goes wrong `opnfv-clean`

## Verification

```
opnfv-util undercloud
source ./stackrc
openstack server list
```

## Tacker

Copy the according script from deps to the host:

- [Colorado](deps/tacker_config.sh)

and execute it:

```bash
chmod +x tacker_config.sh
./tacker_config.sh
./tacker_config.sh

Tacker running on Controller: 192.0.2.5\.  Please ssh heat-admin@192.0.2.5 to access

source sfcrc
```

## SFC/VNF demo

[Readme](docs/Readme.md)

# Clean up

```bash
opnfv-clean
```
