# SFC Demo with Tacker

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
curl -sLo /tmp/sf_nsh_colorado.qcow2 http://artifacts.opnfv.org/sfc/demo/sf_nsh_colorado.qcow2

# Upload the image
glance image-create --visibility=public --name=sfc_demo_image --disk-format=qcow2 --container-format=bare --file=/tmp/sf_nsh_colorado.qcow2 --progress
glance image-list

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
SECURITY_GROUP_NAME=sfc_demo_sg

neutron security-group-create ${SECURITY_GROUP_NAME} --description "Example SFC Security group"
neutron security-group-list

neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 80 --port-range-max 80 --direction ingress
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 443 --port-range-max 443 --direction ingress
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 22 --port-range-max 22 --direction egress
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 80 --port-range-max 80 --direction egress
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 443 --port-range-max 443 --direction egress
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol icmp

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
# This step is optional
ssh-keygen -t rsa -b 4096 -f ~/.ssh/sfc_demo -C doesnotmatter@sfc_demo
nova keypair-add --pub-key ~/.ssh/sfc_demo.pub sfc_demo_key
nova keypair-list
```

### Create instances

```bash
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups ${SECURITY_GROUP_NAME} --nic net-name=sfc_demo_net client
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups ${SECURITY_GROUP_NAME} --nic net-name=sfc_demo_net server
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
sudo ufw disable
sudo sh -c "while true; do { echo -n 'HTTP/1.1 200 OK\n\nHello World\n'; } | nc -l 80 > /dev/null; done" &
# Test it
curl --connect-timeout 5 http://localhost
```

### Client Test

```bash
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP
while true; do curl --connect-timeout 2 http://<server-internal>; sleep2; done
```

## VNFD

Copy the files [VNFD 1](../sfc-files/test-vfnd1.yaml) and [VNFD 2](../sfc-files/test-vfnd2.yaml) to the Host and create a VNFD:

```bash
tacker vnfd-create --vnfd-file ./test-vnfd1.yaml
tacker vnfd-create --vnfd-file ./test-vnfd2.yaml
tacker vnfd-list
```

Now we can deploy the VNF:

```bash
tacker vnf-create --name testVNF1 --vnfd-name test-vnfd1
tacker vnf-create --name testVNF2 --vnfd-name test-vnfd2
# Check the status
heat stack-list
tacker vnf-list
```

### Start VNFs

To be able to login into the VNFs we need to create a floating IP.

```bash
VNF1_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
# Fetch the ID of the VNF 1
nova list
VNF1_ID=""

VNF1_ID=efd76fc5-26c4-4799-ade2-1c2730eca140
VNF1_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep ${VNF1_ID} | awk {'print $2'}))
neutron floatingip-associate $VNF1_FIP_ID $VNF1_PORT
VNF1_FIP=$(neutron floatingip-show -c floating_ip_address -f value $VNF1_FIP_ID)
# test SSH (at this time we still have the OPNFV image)
sshpass -p opnfv ssh root@$VNF1_FIP 'cd /root;nohup python vxlan_tool.py -i eth0 -d forward -v off -b 80 > /root/vxlan.log  2>&1 &'
```

The same for VNF2:

```bash
VNF2_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
# Fetch the ID of the VNF 1
nova list
VNF2_ID=""
VNF2_ID=5ec108a7-c709-4d1f-b9ad-2429a7a790ab
VNF2_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep ${VNF2_ID} | awk {'print $2'}))
neutron floatingip-associate $VNF2_FIP_ID $VNF2_PORT
VNF2_FIP=$(neutron floatingip-show -c floating_ip_address -f value $VNF2_FIP_ID)
sshpass -p opnfv ssh root@$VNF2_FIP 'cd /root;nohup python vxlan_tool.py -i eth0 -d forward -v off -b 22 > /root/vxlan.log  2>&1 &'
```

## SFC

### Create SFC

```bash
#create service chain
tacker sfc-create --name red --chain testVNF1
tacker sfc-create --name blue --chain testVNF2
tacker sfc-list
```

### Create SFC classifiers

```bash
#create classifier
tacker sfc-classifier-create --name red_http --chain red --match source_port=0,dest_port=80,protocol=6
tacker sfc-classifier-create --name red_ssh --chain red --match source_port=0,dest_port=22,protocol=6
tacker sfc-classifier-list
```

## Recreate SFC classifiers

```bash
tacker sfc-classifier-delete red_http
tacker sfc-classifier-delete red_ssh

tacker sfc-classifier-create --name blue_http --chain blue --match source_port=0,dest_port=80,protocol=6
tacker sfc-classifier-create --name blue_ssh  --chain blue --match source_port=0,dest_port=22,protocol=6
tacker sfc-classifier-list
```

# Clean Up

```bash
# Delete VNFDs
tacker device-delete testVNF1
tacker device-delete testVNF2

tacker device-template-delete test-vnfd1
tacker device-template-delete test-vnfd2

nova flavor-delete sfc_demo_flavor
glance image-delete $(glance image-list | grep sfc_demo_image | awk '{print $2}')

nova delete client server

neutron router-gateway-clear sfc_demo_router
neutron router-interface-delete sfc_demo_router subnet=sfc_demo_net_subnet
neutron router-delete sfc_demo_router
neutron net-delete sfc_demo_net
neutron security-group-delete sfc_demo_sg

tacker sfc-classifier-delete blue_http
tacker sfc-classifier-delete blue_ssh

tacker sfc-delete blue
tacker sfc-delete red

nova delete client server
```

There seems to be a little problem with cleaning up the classifiers, when you delete the classifiers with `tacker sfc-classifier-delete <name>` the ovs rules stay (until they get overwritten).
