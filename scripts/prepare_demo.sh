#!/bin/bash
#TODO create script 
iptables -P INPUT ACCEPT
iptables -t nat -P INPUT ACCEPT
iptables -A INPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Now we prepare the compute nodes
ssh_options='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
SSH_INSTALLER="sshpass -p r00tme ssh $ssh_options root@10.20.0.2"

for i in $(${SSH_INSTALLER} 'fuel node'|grep compute| awk '{print $9}'); do ${SSH_INSTALLER} 'ssh root@'"$i"' ifconfig br-int up'; ${SSH_INSTALLER} 'ssh root@'"$i"' ip route add 11.0.0.0/24 dev br-int'; done

curl -sLo /tmp/sf_nsh_colorado.qcow2 http://artifacts.opnfv.org/sfc/demo/sf_nsh_colorado.qcow2

. tackerc

# Upload the image
#TODO  if image exists dont execute
glance image-create --visibility=public --name=sfc_demo_image --disk-format=qcow2 --container-format=bare --file=/tmp/sf_nsh_colorado.qcow2 --progress

# Create a new flavor
#TODO  if flavor exists dont execute
nova flavor-create --is-public=true sfc_demo_flavor auto 1500 10 1


neutron net-create sfc_demo_net --provider:network_type=vxlan --provider:segmentation_id 1005
neutron subnet-create --dns-nameserver 8.8.8.8 sfc_demo_net 11.0.0.0/24 --name sfc_demo_net_subnet
neutron router-create sfc_demo_router
neutron router-interface-add sfc_demo_router subnet=sfc_demo_net_subnet
neutron router-gateway-set sfc_demo_router admin_floating_net


neutron security-group-create sfc_demo_sg --description "Example SFC Security group"

neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 80 --port-range-max 80 --direction ingress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 443 --port-range-max 443 --direction ingress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 22 --port-range-max 22 --direction egress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 80 --port-range-max 80 --direction egress
neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 443 --port-range-max 443 --direction egress
neutron security-group-rule-create sfc_demo_sg --protocol icmp

for i in $(neutron security-group-list -c id -f value); do
  neutron security-group-rule-create $i --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress
  neutron security-group-rule-create $i --protocol tcp --port-range-min 22 --port-range-max 22 --direction egress --remote-ip 10.0.0.0/8
done

neutron security-group-list
neutron security-group-rule-list

curl -sLo /tmp/ubuntu_xenial.img http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
glance image-create --visibility=public --name=ubuntu-xenial --disk-format=qcow2 --container-format=bare --file=/tmp/ubuntu_xenial.img --progress


ssh-keygen -N '' -t rsa -b 4096 -f ~/.ssh/sfc_demo -C doesnotmatter@sfc_demo
nova keypair-add --pub-key ~/.ssh/sfc_demo.pub sfc_demo_key
nova keypair-list

nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net client
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net server
# TODO better grep for "running"
sleep 15
nova list

CLIENT_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
CLIENT_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep client | awk {'print $2'}))
neutron floatingip-associate $CLIENT_FIP_ID $CLIENT_PORT
CLIENT_FIP=$(neutron floatingip-show -c floating_ip_address -f value $CLIENT_FIP_ID)
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP echo 'Hello Client'

SERVER_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
SERVER_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep server | awk {'print $2'}))
neutron floatingip-associate $SERVER_FIP_ID $SERVER_PORT
SERVER_FIP=$(neutron floatingip-show -c floating_ip_address -f value $SERVER_FIP_ID)
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP echo 'Hello Server'

# TODO
ssh -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP sudo sh -c "while true; do { echo -n 'HTTP/1.1 200 OK\n\nHello World\n'; } | nc -l 80 > /dev/null; done" &

# TODO
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP
while true; do curl --connect-timeout 2 http://<server-internal>; sleep 2; done


# TODO echo -e "template_name: test-vnfd
description: firewall-example

curl -slo test-vnfd.yaml <githuburl>

# TODO SFC part

tacker vnfd-create --vnfd-file ./test-vnfd.yaml

tacker vnf-create --name testVNF --vnfd-name test-vnfd

# TODO wait for running

tacker vnf-list

VNF_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
VNF_ID=$(nova list | grep ta- | awk {'print $2'})
VNF_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep ${VNF_ID} | awk {'print $2'}))
neutron floatingip-associate $VNF_FIP_ID $VNF_PORT
VNF_FIP=$(neutron floatingip-show -c floating_ip_address -f value $VNF_FIP_ID)
sshpass -p opnfv ssh root@$VNF_FIP 'echo Hello'

sshpass -p opnfv ssh root@$VNF_FIP python vxlan_tool.py -i eth0 -d forward -v off -b 80


tacker sfc-create --name testchain --chain testVNF

tacker sfc-classifier-create --name test_http --chain testchain --match source_port=0,dest_port=80,protocol=6

tacker sfc-classifier-create --name test_ssh --chain testchain --match source_port=0,dest_port=22,protocol=6

# TODO
sshpass -p opnfv ssh root@$VNF_FIP python vxlan_tool.py -i eth0 -d forward -v off -b 22

exit

# TODO clean up step

# Delete VNFDs
tacker device-delete testVNF
tacker device-template-delete test-vnfd
tacker sfc-classifier-delete test_http
tacker sfc-classifier-delete test_ssh
tacker sfc-delete testchain

nova delete client server

for i in $(neutron port-list | grep 11.0.0\. | awk '{print $2}'); do neutron port-delete $i; done
neutron router-gateway-clear sfc_demo_router
neutron router-interface-delete sfc_demo_router subnet=sfc_demo_net_subnet
neutron router-delete sfc_demo_router
neutron net-delete sfc_demo_net
neutron security-group-delete sfc_demo_sg
