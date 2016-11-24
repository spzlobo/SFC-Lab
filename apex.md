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
```

### Heat Controller

```bash
source sfcrc
neutron net-create net_mgmt --provider:network_type=vxlan --provider:segmentation_id 1005
neutron subnet-create net_mgmt 123.123.123.0/24
```

### Glance SFC Image

```bash
curl -sLo /tmp/sfc_cloud.qcow2 https://www.dropbox.com/s/focu44sh52li7fz/sfc_cloud.qcow2
openstack image create sfc --disk-format qcow2 --public --file /tmp/sfc_cloud.qcow2
openstack flavor create custom --ram 1000 --disk 5 --public
```

### VNFD

Copy the file [VNFD](./test-vnfd.yaml) to the Host and create a VNFD:

```bash
tacker vnfd-create --vnfd-file ./test-vnfd.yaml
# if you want to delete it tacker vnfd-delete test-vnfd
```

Now we can deploy the VNFs:

```bash
tacker vnf-create --name testVNF1 --vnfd-name test-vnfd
# if you want to delete it tacker vnf-delete testVNF1
# Check the status
heat stack-list
# List all VNFs
tacker vnf-list
# Port forward from remote machine
ssh -t root@<remote> -L 8000:<heat-vm>:80 -L 6080:<heat-vm>:6080
```

Now go to

<localhost:8000> and login as <code>tacker</code> <code>tacker</code> in the Horizon UI </localhost:8000>

go to Compute->Instances and select the VNF instance select Console and login as `root` `octopus`

And configure the VNF (this should be automated, like cloud-init or something else):

```bash
service iptables stop
python ~/vxlan_tool/vxlan_tool.py -i eth0 -d forward -v on
```

### HTTP Server and client

#### SSH keys

Create a new one

```bash
nova keypair-add overcloud > overcloud.pem
chmod 600 overcloud.pem
nova keypair-list
```

Add existing

```bash
nova keypair-add --pub-key ~/.ssh/id_rsa.pub KEY_NAME
nova keypair-list
```

#### Create instances

Create at first a `cloud-init.yaml` file:

```yaml
tee cloud-init.yaml <<-'EOF'
#cloud-config
ssh_pwauth: True
password: demo
chpasswd:
  list: |
    ubuntu:demo
  expire: False
EOF
```

```bash
curl -sLo /tmp/ubuntu.img https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
openstack image create UbuntuXenial --disk-format qcow2 --public --file /tmp/ubuntu.img

curl -sLo /tmp/cirros.img http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
openstack image create cirros --disk-format qcow2 --public --file /tmp/cirros.img

#username: cirros
#password: cubswin:)
nova boot --flavor m1.tiny --image cirros --nic net-name=net_mgmt --key-name overcloud http_client

nova boot --flavor m1.small --image sfc --nic net-name=net_mgmt --key-name overcloud http_server #1000MB  5GB disk

# http_server, and disable iptables: "service iptables stop"
# Start simple python http server: "python -m SimpleHTTPServer 80"
```

### SFC

```bash
tacker sfc-create --name mychain --chain testVNF1
tacker sfc-show mychain # Should be 'active'
```

#### Validate OVS flows

```bash
sudo ovs-ofctl -O OpenFlow13 dump-flows br-int
```

#### SFC classifier

```bash
tacker sfc-classifier-create --name myclass --chain mychain --match source_port=2000,dest_port=80,protocol=6
sudo ovs-ofctl dump-flows br-int -O openflow13 | grep tp_dst=80
```

### VXLAN

```bash
opnfv-util overcloud compute0 heat-admin
sudo ifconfig br-int up
sudo ip route add 123.123.123.0/24 dev br-int

opnfv-util overcloud compute1 heat-admin
sudo ifconfig br-int up
sudo ip route add 123.123.123.0/24 dev br-int
```

```
  11\. Test SFC!
    a.  Go to horizon, click Compute->Instances, note the IP of the http server/http client
    b.  Now click the VNF and go to its console
    c.  On the VM terminal "ip netns list" to find the ID of the qdhcp namespace
    d.  ip netns exec <qdhcp ns ID> ssh cirros@<http client ip>; password is cubswin:)
    e.  Now in cirros, curl --local-port 2000 <http server ip>
    f.  Verify you see packets being redirected through the SFC (hitting the VNF in the horizon console)
    g.  Verify you receive 200 OK response from the http server
```

# Clean up

```bash
opnfv-clean
```
