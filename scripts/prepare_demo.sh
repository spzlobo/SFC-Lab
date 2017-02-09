#!/bin/bash

# TODO add args

function clean_up {
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
}

function vxlan_workaround {
  echo "Running VXLAN workaround"
  iptables -P INPUT ACCEPT
  iptables -t nat -P INPUT ACCEPT
  iptables -A INPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

  # Now we prepare the compute nodes
  ssh_options='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
  SSH_INSTALLER="sshpass -p r00tme ssh $ssh_options root@10.20.0.2"

  for i in $(${SSH_INSTALLER} 'fuel node'|grep compute| awk '{print $9}'); do
    ${SSH_INSTALLER} 'ssh root@'"$i"' ifconfig br-int up' &> /dev/null;
    ${SSH_INSTALLER} 'ssh root@'"$i"' ip route add 11.0.0.0/24 dev br-int' &> /dev/null;
  done
}

vxlan_workaround()
. tackerc

if [[ $(glance image-list | grep sfc_demo_image | wc -l) -eq 0 ]]; then
  echo "Download and create SFC demo image"
  curl -sLo /tmp/sf_nsh_colorado.qcow2 http://artifacts.opnfv.org/sfc/demo/sf_nsh_colorado.qcow2
  glance image-create --visibility=public --name=sfc_demo_image --disk-format=qcow2 --container-format=bare --file=/tmp/sf_nsh_colorado.qcow2 --tags sfc --progress
fi

if [[ $(glance image-list | grep ubuntu-xenial | wc -l) -eq 0 ]]; then
  echo "Download and create Ubuntu Xenial image"
  curl -sLo /tmp/ubuntu_xenial.img http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
  glance image-create --visibility=public --name=ubuntu-xenial --disk-format=qcow2 --container-format=bare --file=/tmp/ubuntu_xenial.img --tags sfc --progress
fi

if ! nova flavor-show sfc_demo_flavor &> /dev/null ; then
  echo "Create SFC Demo flavor"
  nova flavor-create --is-public=true sfc_demo_flavor auto 1500 10 1
fi

if ! neutron net-show sfc_demo_net &> /dev/null ; then
  echo "Creating Network and Security Groups"
  neutron net-create sfc_demo_net --provider:network_type=vxlan --provider:segmentation_id 1005 > /dev/null
  neutron subnet-create --dns-nameserver 8.8.8.8 sfc_demo_net 11.0.0.0/24 --name sfc_demo_net_subnet > /dev/null
  neutron router-create sfc_demo_router > /dev/null
  neutron router-interface-add sfc_demo_router subnet=sfc_demo_net_subnet > /dev/null
  neutron router-gateway-set sfc_demo_router admin_floating_net > /dev/null
  neutron security-group-create sfc_demo_sg --description "Example SFC Security group" > /dev/null

  neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress > /dev/null
  neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 80 --port-range-max 80 --direction ingress > /dev/null
  neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 443 --port-range-max 443 --direction ingress > /dev/null
  neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 22 --port-range-max 22 --direction egress > /dev/null
  neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 80 --port-range-max 80 --direction egress > /dev/null
  neutron security-group-rule-create sfc_demo_sg --protocol tcp --port-range-min 443 --port-range-max 443 --direction egress > /dev/null
  neutron security-group-rule-create sfc_demo_sg --protocol icmp > /dev/null

  for i in $(neutron security-group-list -c id -f value); do
    neutron security-group-rule-create $i --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress > /dev/null
    neutron security-group-rule-create $i --protocol tcp --port-range-min 22 --port-range-max 22 --direction egress --remote-ip 10.0.0.0/8 > /dev/null
  done
fi

if ! nova keypair-show sfc_demo_key &> /dev/null ; then
  echo "Creating SSH Keypair in $(echo ~/.ssh/sfc_demo)"
  ssh-keygen -N '' -t rsa -b 4096 -f ~/.ssh/sfc_demo -C doesnotmatter@sfc_demo > /dev/null
  nova keypair-add --pub-key ~/.ssh/sfc_demo.pub sfc_demo_key > /dev/null
fi

CLIENT_FIP_NEEDED=false
if ! nova show client &> /dev/null ; then
  CLIENT_FIP_NEEDED=true
  echo "Creating Client VM"
  nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net client > /dev/null
fi

SERBER_FIP_NEEDED=false
if ! nova show server &> /dev/null ; then
  echo "Creating Server VM"
  SERBER_FIP_NEEDED=true
  nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net server > /dev/null
fi

while [[ $(nova show client --minimal | grep ACTIVE | wc -l ) -eq 0 || $(nova show server --minimal | grep ACTIVE | wc -l ) -eq 0 ]];
do
  echo "Waiting for Client and Server VM to come up"
  sleep 10
done

if $CLIENT_FIP_NEEDED; then
  echo "Create Floating IP for Client VM"
  CLIENT_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
  CLIENT_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep client | awk {'print $2'}))
  neutron floatingip-associate $CLIENT_FIP_ID $CLIENT_PORT
  CLIENT_FIP=$(neutron floatingip-show -c floating_ip_address -f value $CLIENT_FIP_ID)
  sleep 5
  # TODO add backoff 5 times
  ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP echo 'Hello Client'
fi

if $SERBER_FIP_NEEDED; then
  echo "Create Floating IP for Server VM"
  SERVER_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
  SERVER_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep server | awk {'print $2'}))
  neutron floatingip-associate $SERVER_FIP_ID $SERVER_PORT
  SERVER_FIP=$(neutron floatingip-show -c floating_ip_address -f value $SERVER_FIP_ID)
  sleep 5
  # TODO add backoff 5 times
  ssh -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP echo 'Hello Server'
fi

# TODO


ssh -t -n -f -i ~/.ssh/sfc_demo ubuntu@$SERVER_FIP 'nohup sudo sh -c "while true; do { echo -n \"HTTP/1.1 200 OK\n\nHello World\n\"; } | nc -l 80; done" > /dev/null 2>&1 &'

#INTERNAL_SERVER_IP=$(nova list | grep server |  awk {'print $12'} |  awk -F = {'print $2'})
# TODO remove hardcoded
ssh -n -f -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP 'nohup while true; do curl --connect-timeout 2 http://11.0.0.5; sleep 2; done > ./http.log 2>&1 &'


if [ ! -f test-vnfd.yaml ]; then
  echo "Download test vnfd file"
  curl -slo test-vnfd.yaml https://raw.githubusercontent.com/johscheuer/SFC-Lab/master/sfc-files/test-vnfd.yaml
fi

if [[ $(tacker vnfd-list -f value | grep test-vnfd | wc -l) -eq 0 ]]; then
  echo "Create VNFD"
  tacker vnfd-create --vnfd-file ./test-vnfd.yaml  > /dev/null
fi

VNF_FIP_NEEDED=false
if [[ $(tacker vnf-list -f value | grep testVNF | wc -l) -eq 0 ]]; then
  VNF_FIP_NEEDED=true
  echo "Create VNF"
  tacker vnf-create --name testVNF --vnfd-name test-vnfd  > /dev/null
fi

while [[ $(tacker vnf-list -f value | grep testVNF | grep ACTIVE | wc -l) -eq 0 ]];
do
  echo "Waiting for VNF to come up"
  sleep 10
done

if $VNF_FIP_NEEDED; then
  echo "Create Floating IP for VNF"
  VNF_FIP_ID=$(neutron floatingip-create admin_floating_net -c id -f value | awk 'NR==2')
  VNF_ID=$(nova list | grep ta- | awk {'print $2'})
  VNF_PORT=$(neutron port-list -c id -f value -- --device_id $(nova list --minimal | grep ${VNF_ID} | awk {'print $2'}))
  neutron floatingip-associate $VNF_FIP_ID $VNF_PORT
  VNF_FIP=$(neutron floatingip-show -c floating_ip_address -f value $VNF_FIP_ID)
  sleep 5
  # TODO add backoff 5 times
  sshpass -p opnfv ssh root@$VNF_FIP 'echo Hello'
fi

#TODO
#sshpass -p opnfv ssh root@$VNF_FIP python vxlan_tool.py -i eth0 -d forward -v off -b 80

if [[ $(tacker sfc-list | grep testchain | wc -l) -eq 0 ]]; then
  echo "Creating SFC Classifiers"
  tacker sfc-create --name testchain --chain testVNF > /dev/null
  tacker sfc-classifier-create --name test_http --chain testchain --match source_port=0,dest_port=80,protocol=6 > /dev/null
  tacker sfc-classifier-create --name test_ssh --chain testchain --match source_port=0,dest_port=22,protocol=6 > /dev/null
fi

# TODO validate HTTP blocked - SSH works

# TODO
#sshpass -p opnfv ssh root@$VNF_FIP python vxlan_tool.py -i eth0 -d forward -v off -b 22

# TODO validate SSH blocked - HTTP works
