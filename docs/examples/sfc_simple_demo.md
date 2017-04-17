# A Simple SFC example

## Setup

## Preparation

This step allows us to ssh into the new created VMs (execute them on the Controller Node):

```bash
iptables -P INPUT ACCEPT
iptables -t nat -P INPUT ACCEPT
iptables -A INPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Now we prepare the compute nodes
ssh_options='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
SSH_INSTALLER="sshpass -p r00tme ssh $ssh_options root@10.20.0.2"

for i in $(${SSH_INSTALLER} 'fuel node'|grep compute| awk '{print $9}'); do ${SSH_INSTALLER} 'ssh root@'"$i"' ifconfig br-int up'; ${SSH_INSTALLER} 'ssh root@'"$i"' ip route add 11.0.0.0/24 dev br-int'; done
```

### Download Ubuntu Xenial image

```bash
curl -sLo /tmp/ubuntu_xenial.img http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
openstack image create --public --disk-format=qcow2 --container-format=bare --file=/tmp/ubuntu_xenial.img ubuntu-xenial
```

### Create SSH keys

This step is optional you can also use your own SSH Key.

```bash
ssh-keygen -N '' -t rsa -b 4096 -f ~/.ssh/sfc_demo -C doesnotmatter@sfc_demo
openstack keypair add --pub-key ~/.ssh/sfc_demo.pub sfc_demo_key
openstack keypair list
```

### Create Flavor

```bash
openstack flavor create --public --ram 1000 --disk 10 --vcpus 1 sfc_demo_flavor
openstack flavor list
```

## Neutron Network

Create at first a Neutron network

```bash
# TODO move these into openstack synatx
neutron net-create sfc_demo_net --provider:network_type=vxlan --provider:segmentation_id 1005
neutron subnet-create --dns-nameserver 8.8.8.8 sfc_demo_net 11.0.0.0/24 --name sfc_demo_net_subnet
neutron router-create sfc_demo_router
neutron router-interface-add sfc_demo_router subnet=sfc_demo_net_subnet
neutron router-gateway-set sfc_demo_router admin_floating_net

neutron router-show sfc_demo_router
neutron router-port-list sfc_demo_router
```

### Security groups

```bash
neutron security-group-create sfc_demo_sg --description "Example SFC Security group"
neutron security-group-list
neutron security-group-rule-create sfc_demo_sg --protocol icmp

neutron security-group-rule-list
```

#### Allow SSH and HTTP(s)

We allow ssh to all VM's

```bash
for i in $(neutron security-group-list -c id -f value); do
  neutron security-group-rule-create $i --protocol tcp --port-range-min 80 --port-range-max 80 --direction ingress
  neutron security-group-rule-create $i --protocol tcp --port-range-min 443 --port-range-max 443 --direction ingress
  neutron security-group-rule-create $i --protocol tcp --port-range-min 80 --port-range-max 80 --direction egress
  neutron security-group-rule-create $i --protocol tcp --port-range-min 443 --port-range-max 443 --direction egress
  neutron security-group-rule-create $i --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress
  neutron security-group-rule-create $i --protocol tcp --port-range-min 22 --port-range-max 22 --direction egress
done

neutron security-group-list
neutron security-group-rule-list
```

## HTTP Server and client

### Create instances

```bash
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net client
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net server
sleep 15
nova list
```

### Create Floating IP Client

```bash
CLIENT_FIP=$(openstack floating ip create admin_floating_net -c floating_ip_address -f value)
openstack server add floating ip client $CLIENT_FIP_ID
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP echo 'Hello Client'
```

# test SSH

```bash
SERVER_FIP=$(openstack floating ip create admin_floating_net -c floating_ip_address -f value)
openstack server add floating ip server $SERVER_FIP
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP echo 'Hello Server'
```

## HTTP server

Stop iptables and start a simple Web server

```bash
ssh -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP
sudo python3 -m http.server 80
# Test it
curl --connect-timeout 5 http://localhost
```

## Client Test

```bash
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP
while true; do curl --connect-timeout 2 http://<server-internal>; sleep 2; done
```

## VNFD

### VNFD files

```bash
echo -e "template_name: http-firewall-vnfd
description: HTTP firewall

service_properties:
  Id: http-firewall-vnfd
  vendor: tacker
  version: 1
  type:
      - firewall
vdus:
  vdu1:
    id: vdu1
    vm_image: ubuntu-xenial
    instance_type: sfc_demo_flavor
    service_type: firewall

    network_interfaces:
      management:
        network: sfc_demo_net
        management: true

    placement_policy:
      availability_zone: nova

    auto-scaling: noop
    monitoring_policy: noop
    failure_policy: respawn

    user_data_format: RAW
    user_data: |
      #cloud-config
      packages:
        - python3
        - curl

      runcmd:
        - [ curl, "https://raw.githubusercontent.com/opendaylight/sfc/master/sfc-test/nsh-tools/vxlan_tool.py", -sLO, /usr/bin/vxlan_tool.py ]
        - [ chmod, +x, /usr/bin/vxlan_tool.py ]
        - [ python3, /usr/bin/vxlan_tool.py, -i eth0, -d forward, -v off, -b 80 ]

      ssh_authorized_keys:
        - \"$(cat ~/.ssh/sfc_demo.pub)\"

    config:
      param0: key0
      param1: key1" > http-firewall-vnfd.yaml
```

### Create VNFDs

```bash
tacker vnfd-create --vnfd-file ./http-firewall-vnfd.yaml
tacker vnfd-list
```

Now we can deploy the VNF:

```bash
tacker vnf-create --name http-firewall --vnfd-name http-firewall-vnfd
# Check the status
openstack stack list
tacker vnf-list
```

### Login VNF

To be able to login into the VNFs we need to create a floating IP.

```bash
VNF_FIP=$(openstack floating ip create admin_floating_net -c floating_ip_address -f value)
openstack server add floating ip $(openstack server list -c Name -f value | grep ta-) $CLIENT_FIP_ID
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$VNF_FIP 'echo Hello'
```

### Migration

The SFC rules are currently not updated when you make a (live) migration.

```
# Get current hypervisor
openstack server show $(openstack server list -c Name -f value | grep ta-) |grep OS-EXT-SRV-ATTR:hypervisor_hostname
# Get all hypervisors
openstack hypervisor list

# Migrate VNF
openstack server migrate --live <NODE> --block-migration $(openstack server list -c Name -f value | grep ta-)
openstack server resize --confirm $(openstack server list -c Name -f value | grep ta-)
```

## SFC

### Create SFC

```bash
tacker sfc-create --name firewall-chain --chain http-firewall
tacker sfc-list
```

### Create SFC classifier for HTTP

```bash
#create classifier
tacker sfc-classifier-create --name http-classifier --chain firewall-chain --match source_port=0,dest_port=80,protocol=6
tacker sfc-classifier-list
```

### Create SFC classifier for SSH

```bash
tacker sfc-classifier-create --name ssh-classifier --chain firewall-chain --match source_port=0,dest_port=22,protocol=6
tacker sfc-classifier-list
```

now we can adjust the firewall:

```bash
sudo pkill python3
sudo python3 vxlan_tool.py -i eth0 -d forward -v off -b  22
```

# Clean Up

```bash
# Delete VNFDs
tacker device-delete http-firewall
tacker device-template-delete http-firewall-vnfd
tacker sfc-classifier-delete http-classifier
tacker sfc-classifier-delete ssh-classifier
tacker sfc-delete firewall-chain

nova delete client server

for i in $(neutron port-list | grep 11.0.0\. | awk '{print $2}'); do neutron port-delete $i; done
neutron router-gateway-clear sfc_demo_router
neutron router-interface-delete sfc_demo_router subnet=sfc_demo_net_subnet
neutron router-delete sfc_demo_router
neutron net-delete sfc_demo_net
neutron security-group-delete sfc_demo_sg
```

There is a bug that not all rules get cleared use this snippet as work around (but be careful):

```bash
ovs-ofctl -O OpenFlow13 del-flows br-int tcp,reg0=0x1,tp_dst=80
ovs-ofctl -O OpenFlow13 del-flows br-int tcp,reg0=0x1,tp_dst=22
ovs-ofctl -O OpenFlow13 del-flows br-int table=11,nsi=254
ovs-ofctl -O OpenFlow13 del-flows br-int table=1,nsi=254
```

# TODO

- [ ] Image of Setup
