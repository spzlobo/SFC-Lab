# A Simple SFC example

## Setup

## Preparation

This step allows us to ssh into the new created VMs (execute them on the Controller Node):

```bash
apt-get install -y sshpass
iptables -P INPUT ACCEPT
iptables -t nat -P INPUT ACCEPT
iptables -A INPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Now we prepare the compute nodes
ssh_options='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
SSH_INSTALLER="sshpass -p r00tme ssh $ssh_options root@10.20.0.2"

for i in $(${SSH_INSTALLER} 'fuel node'|grep compute| awk '{print $9}'); do ${SSH_INSTALLER} 'ssh root@'"$i"' ifconfig br-int up'; ${SSH_INSTALLER} 'ssh root@'"$i"' ip route add 11.0.0.0/24 dev br-int'; done
```

## SF Image

We use the official image from OPNFV (as long as we didn't created our own):

```bash
#curl -sLo /tmp/sf_nsh_colorado.qcow2 http://artifacts.opnfv.org/sfc/demo/sf_nsh_colorado.qcow2

# Upload the image
#glance image-create --visibility=public --name=sfc_demo_image --disk-format=qcow2 --container-format=bare --file=/tmp/sf_nsh_colorado.qcow2 --progress
#glance image-list

# Create a new flavor
nova flavor-create --is-public=true sfc_demo_flavor auto 1500 10 1
nova flavor-list
```

## Neutron Network

Create at first a Neutron network

```bash
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

neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 80 --port-range-max 80 --direction ingress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 443 --port-range-max 443 --direction ingress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 22 --port-range-max 22 --direction egress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 80 --port-range-max 80 --direction egress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 443 --port-range-max 443 --direction egress
neutron security-group-rule-create sfc_demo_sg --protocol icmp

neutron security-group-rule-list
```

## HTTP Server and client

### Download Ubuntu Xenial image

```bash
curl -sLo /tmp/ubuntu_xenial.img http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
glance image-create --visibility=public --name=ubuntu-xenial --disk-format=qcow2 --container-format=bare --file=/tmp/ubuntu_xenial.img --progress
```

### Create SSH keys

```bash
ssh-keygen -N '' -t rsa -b 4096 -f ~/.ssh/sfc_demo -C doesnotmatter@sfc_demo
nova keypair-add --pub-key ~/.ssh/sfc_demo.pub sfc_demo_key
nova keypair-list
```

### Create instances

```bash
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net client
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net server
nova list
```

### Create Floating IP Client

```bash
# Bad output format in OpenStack... 'Associated floating IP 1adc93fe-382c-4777-94b4-400604dd5ccf'
CLIENT_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
CLIENT_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep client | awk {'print $2'}))
neutron floatingip-associate $CLIENT_FIP_ID $CLIENT_PORT
CLIENT_FIP=$(neutron floatingip-show -c floating_ip_address -f value $CLIENT_FIP_ID)
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP echo 'Hello World'
```

### Create Floating IP Server

```bash
SERVER_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
SERVER_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep server | awk {'print $2'}))
neutron floatingip-associate $SERVER_FIP_ID $SERVER_PORT
SERVER_FIP=$(neutron floatingip-show -c floating_ip_address -f value $SERVER_FIP_ID)
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP echo 'Hello World'
```

### HTTP server

Stop iptables and start a simple Web server

```bash
ssh -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP
sudo sh -c "while true; do { echo -n 'HTTP/1.1 200 OK\n\nHello World\n'; } | nc -l 80 > /dev/null; done" &
# Test it
curl --connect-timeout 5 http://localhost
```

### Client Test

```bash
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP
while true; do curl --connect-timeout 2 http://<server-internal>; sleep 2; done
```

## VNFD

### VNFD files

**_TODO_** add ssh key id

```bash
echo -e "template_name: test-vnfd
description: firewall1-example

service_properties:
  Id: firewall1-vnfd
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

    config:
      param0: key0
      param1: key1" > test-vnfd.yaml
```

or optional copy the file [VNFD](../sfc-files/test-vfnd.yaml) to the Host and create a VNFD:

### Create VNFDs

```bash
tacker vnfd-create --vnfd-file ./test-vnfd.yaml
tacker vnfd-list
```

Now we can deploy the VNF:

```bash
tacker vnf-create --name testVNF --vnfd-name test-vnfd
# Check the status
heat stack-list
tacker vnf-list
```

### Start VNF

To be able to login into the VNFs we need to create a floating IP.

```bash
VNF_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
VNF_ID=""
VNF_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep ${VNF_ID} | awk {'print $2'}))
neutron floatingip-associate $VNF_FIP_ID $VNF_PORT
VNF_FIP=$(neutron floatingip-show -c floating_ip_address -f value $VNF_FIP_ID)
ssh -i ~/.ssh/sfc_demo ubuntu@$VNF_FIP 'echo Hello'
```

#### Setup VNF

```bash
scp  -i ~/.ssh/sfc_demo <path-sf> ubuntu@$VNF_FIP:/usr/local/bin
ssh -i ~/.ssh/sfc_demo ubuntu@$VNF_FIP
# everything happens on the remote maschine
apt-get install -qq -y python
nohup python vxlan_tool.py -i eth0 -d forward -v off -b 80 > vxlan.log  2>&1 &
```

## SFC

### Create SFC

```bash
tacker sfc-create --name testchain --chain testVNF
tacker sfc-list
```

### Create SFC classifiers for HTTP

```bash
#create classifier
tacker sfc-classifier-create --name test_http --chain testchain --match source_port=0,dest_port=80,protocol=6
tacker sfc-classifier-list
```

## Recreate SFC classifiers

```bash
tacker sfc-classifier-create --name test_ssh --chain testchain --match source_port=0,dest_port=22,protocol=6
tacker sfc-classifier-list
```

# Clean Up

```bash
# Delete VNFDs
tacker device-delete testVNF
tacker device-template-delete test-vnfd
tacker sfc-classifier-delete test_http
tacker sfc-classifier-delete test_ssh
tacker sfc-delete testchain

#nova flavor-delete sfc_demo_flavor
#glance image-delete $(glance image-list | grep sfc_demo_image | awk '{print $2}')

nova delete client server

for i in $(neutron port-list | grep 11.0.0\. | awk '{print $2}'); do neutron port-delete $i; done
neutron router-gateway-clear sfc_demo_router
neutron router-interface-delete sfc_demo_router subnet=sfc_demo_net_subnet
neutron router-delete sfc_demo_router
neutron net-delete sfc_demo_net
neutron security-group-delete sfc_demo_sg
```

# TODO

- [ ] Image of Setup
- [ ] Clean up SFC ACL (OVSDB)

```bash
ACL_NAME=red-http
curl -X DELETE -u admin:admin 172.16.0.3:8181/restconf/config/ietf-access-control-list:access-lists/acl/ietf-access-control-list:ipv4-acl/red-http
```
