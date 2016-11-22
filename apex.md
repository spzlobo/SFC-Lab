# OPNFV SFC with Apex

## TODO

- Create automated setup with Ansible

## Source

Initial idea: <https://github.com/trozet/sfc-random>

## Prerequisites

- CentOS 7 (16GB, 40GB HDD)

### Create stack user

```
adduser -m --password stack --gecos "" stack
echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
```

## Binaries

### Dependencies

```bash
curl -sLo /tmp/python3-ipmi.noarch.rpm http://artifacts.opnfv.org/apex/dependencies/python3-ipmi-0.3.0-1.noarch.rpm &
curl -sLo /tmp/python3-jinja2.noarch.rpm http://artifacts.opnfv.org/apex/dependencies/python3-jinja2-2.8-5.el7.centos.noarch.rpm &
curl -sLo /tmp/python-markupsafe34.centos.src.rpm http://artifacts.opnfv.org/apex/dependencies/python34-markupsafe-0.23-9.el7.centos.x86_64.rpm &
```

### Brahmaputra

```bash
curl -sLo /tmp/opnfv-apex-opendaylight-sfc.noarch.rpm http://artifacts.opnfv.org/apex/brahmaputra/opnfv-apex-opendaylight-sfc-2.3-brahmaputra.3.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-common.noarch.rpm http://artifacts.opnfv.org/apex/brahmaputra/opnfv-apex-common-2.3-brahmaputra.3.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-undercloud.noarch.rpm http://artifacts.opnfv.org/apex/brahmaputra/opnfv-apex-undercloud-2.3-brahmaputra.3.0.noarch.rpm &
```

### Colorado

```bash
curl -sLo /tmp/opnfv-apex-opendaylight-sfc.noarch.rpm http://artifacts.opnfv.org/apex/colorado/opnfv-apex-opendaylight-sfc-3.0--colorado-1.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-common.noarch.rpm  http://artifacts.opnfv.org/apex/colorado/opnfv-apex-undercloud-3.0-colorado-1.0.noarch.rpm &
curl -sLo /tmp/opnfv-apex-undercloud.noarch.rpm http://artifacts.opnfv.org/apex/colorado/opnfv-apex-common-colorado-1.0.noarch.rpm &
```

Install the rpms

```bash
yum -y install epel-release python-pip qemu-kvm qemu-img virt-manager libvirt libvirt-python libvirt-client virt-install virt-viewer
curl -sL https://bootstrap.pypa.io/get-pip.py | python3.4
yum -y groupinstall "Virtualization Host" chkconfig libvirtd on
yum -y install https://www.rdoproject.org/repos/rdo-release.rpm
yum -y update
# Validate that curl has finished
ps -aux | grep curl
reboot

yum -y install /tmp/*.rpm
```

## Nested virt.

```bash
echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
modprobe -r kvm_intel
modprobe kvm_intel

cat /sys/module/kvm_intel/parameters/nested
Y

modinfo kvm_intel | grep nested
parm:           nested:bool

systemctl restart libvirtd
```

## OPNFV deploy

```bash
su stack
sudo opnfv-deploy -v -d /etc/opnfv-apex/os-odl_l2-sfc-noha.yaml -n /etc/opnfv-apex/network_settings.yaml
exit #we can be root again
```

Crap a coffee :D If something goes wrong `opnfv-clean`

## Tacker

Copy the according script from deps to the host:

- [Colorado](deps/tacker_colorado_config.sh)
- [Brahmaputra](deps/tacker_config.sh)

and execute it:

```bash
chmod +x tacker_config.sh
./tacker_config.sh

Tacker running on Controller: 192.0.2.5\.  Please ssh heat-admin@192.0.2.5 to access
```

### Heat Controller

```bash
source sfcrc
neutron net-create net_mgmt --provider:network_type=vxlan --provider:segmentation_id 1005
neutron subnet-create net_mgmt 123.123.123.0/24
```

#### Glance SFC Image

```bash
curl -LO https://www.dropbox.com/s/focu44sh52li7fz/sfc_cloud.qcow2
openstack image create sfc --public --file ./sfc_cloud.qcow2
openstack flavor create custom --ram 1000 --disk 5 --public
```

#### VNFD

Copy the file

<test-vnfd.yaml> to the Host and create a VNFD:</test-vnfd.yaml>

```bash
tacker vnfd-create --vnfd-file ./test-vnfd.yaml
```

Now we can deploy the VNFs:

```bash
tacker vnf-create --name testVNF1 --vnfd-name test-vnfd
# Check the status
heat stack-list
# List all VNFs
tacker vnf-list
```
