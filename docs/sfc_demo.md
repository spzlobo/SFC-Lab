# SFC Demo with Tacker

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
neutron net-create sfc_demo_net
# --dns-nameservers list=true 8.8.8.8
neutron subnet-create sfc_demo_net 11.0.0.0/24 --name sfc_demo_net_subnet
neutron router-create sfc_router
neutron router-interface-add sfc_router subnet=sfc_demo_net_subnet
neutron router-gateway-set sfc_router admin_floating_net
```

### Security groups

```bash
SECURITY_GROUP_NAME=sfc_demo_sg

neutron security-group-create ${SECURITY_GROUP_NAME} --description "Example SFC Security group"
neutron security-group-list

neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 22 --port-range-max 22
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 67 --port-range-max 68
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 80 --port-range-max 80
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol tcp --port-range-min 443 --port-range-max 443
neutron security-group-rule-create ${SECURITY_GROUP_NAME} --protocol icmp

#--ingress | --egress
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
# sudo systemctl stop iptables
echo "Hello World!" > hello.txt
sudo sh -c "while true; do { echo -e 'HTTP/1.1 200 OK\r\n'; cat hello.txt; } | nc -l 80; done " &
# Test it
curl http://localhost
```

### Client Test

```bash
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP
curl http://<server-internal>
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

### Create Floating IPs

```bash
service iptables stop
python ~/vxlan_tool/vxlan_tool.py -i eth0 -d forward -v on
```

## SFC

```bash
##create service chain
#tacker sfc-create --name red --chain testVNF1
#tacker sfc-create --name blue --chain testVNF2

#create classifier
#tacker sfc-classifier-create --name red_http --chain red --match source_port=0,dest_port=80,protocol=6
#tacker sfc-classifier-create --name red_ssh --chain red --match source_port=0,dest_port=22,protocol=6

#tacker sfc-list
#tacker sfc-classifier-list

tacker sfc-create --name mychain --chain testVNF1
tacker sfc-show mychain # Should be 'active'
```

### Validate OVS flows

```bash
sudo ovs-ofctl -O OpenFlow13 dump-flows br-int
```

### SFC classifier

```bash
tacker sfc-classifier-create --name myclass --chain mychain --match source_port=2000,dest_port=80,protocol=6
tacker sfc-classifier-show myclass

# Find the according compute machine
sudo ovs-ofctl dump-flows br-int -O openflow13 | grep tp_dst=80
```

## VXLAN (Workaround)

Validate this step!

Execute this step on the Controller and all Compute nodes:

```bash
sudo ifconfig br-int up
sudo ip route add 123.123.123.0/24 dev br-int

ssh root@10.20.0.5 "ifconfig br-int up && ip route add 123.123.123.0/24 dev br-int"
ssh root@10.20.0.6 "ifconfig br-int up && ip route add 123.123.123.0/24 dev br-int"
```

## Test SFC!

Go to the Compute->Instances view and note the ip of the HTTTP server/client. Login in into the HTTP client and Curl the server:

```bash
curl --local-port 2000 -I <HTTP server IP>
```

Verify that the packets hit the VNF and the client receive a 200 OK as response

<http://ehaselwanter.com/en/blog/2014/10/15/deploying-openstack-with-mirantis-fuel-5-1/>

<http://docs.openstack.org/developer/fuel-docs/userdocs/fuel-install-guide/install/install_set_up_fuel.html#install-set-up-fuel>

# Clean Up

```bash
# Delete VNFDs
tacker device-delete testVNF1
tacker device-delete testVNF2

tacker device-template-delete test-vnfd1
tacker device-template-delete test-vnfd2

nova flavor-delete sfc_demo_flavor
glance image-delete $(glance image-list | grep sfc_demo_image | awk '{print $2}')
```

## TODO

- [ ] Own SF image
