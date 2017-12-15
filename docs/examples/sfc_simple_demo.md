# A Simple SFC example without tacker

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
openstack keypair create --public-key ~/.ssh/sfc_demo.pub sfc_demo_key
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

#openstack network create --provider-network-type vxlan --provider-segment 1005 sfc_demo_net
#openstack subnet create --dns-nameserver 8.8.8.8 --network sfc_demo_net --subnet-range 11.0.0.0/24 sfc_demo_net_subnet
#openstack router create sfc_demo_router
#openstack router set --route admin_floating_net sfc_demo_router
#openstack router add subnet sfc_demo_router sfc_demo_net_subnet

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
nova boot --flavor sfc_demo_flavor --image ubuntu-xenial --key-name sfc_demo_key --security-groups sfc_demo_sg --nic net-name=sfc_demo_net sf
sleep 15
openstack server list
```

### Create Floating IP Client

```bash
CLIENT_FIP=$(openstack floating ip create admin_floating_net -c floating_ip_address -f value)
openstack server add floating ip client $CLIENT_FIP
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$CLIENT_FIP echo 'Hello Client'
```


### Create Floating IP Server

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

### Create Floating IP SF Firewall

```bash
SF_FIP=$(openstack floating ip create admin_floating_net -c floating_ip_address -f value)
openstack server add floating ip sf $SF_FIP
# test SSH
ssh -i ~/.ssh/sfc_demo ubuntu@$SF_FIP echo 'Hello sf'
```

### Configure SF Firewall

```bash
ssh -i ~/.ssh/sfc_demo ubuntu@$SF_FIP 
sudo apt-get install python
sudo apt-get install curl
curl https://raw.githubusercontent.com/opendaylight/sfc/master/sfc-test/nsh-tools/vxlan_tool.py > /usr/bin/vxlan_tool.py 
chmod +x /usr/bin/vxlan_tool.py 
sudo python vxlan_tool.py -i eth0 -d forward -v on

```


Configure ODL via API REST:
==========================
http://IP_Controller:8181/apidoc/explorer/index.html


## SFC

### Create Service Function

http://10.6.71.65:8181/restconf/config/service-function:service-function   //
POST

```bash
{
  "service-functions": {
    "service-function": [
      {
        "name": "sf2",
        "sf-data-plane-locator": [
          {
            "name": "sf2-dpl",
            "service-function-ovs:ovs-port": {
              "port-id": "tap7529a4ca-cd"
            },
            "ip": "11.0.0.12",
            "port": 6633,
            "service-function-forwarder": "sff-192.168.8.4",
            "transport": "service-locator:vxlan-gpe"
          }
        ],
        "nsh-aware": true,
        "ip-mgmt-address": "11.0.0.12",
        "type": "firewall"
      }
    ]
  }
}
```
### Create Service Function Forwarders

http://10.6.71.65:8181/restconf/config/service-function-forwarder:service-function-forwarders/
POST

```bash
{
  "service-function-forwarders": {
    "service-function-forwarder": [
      {
        "name": "sff-192.168.8.4",
        "ip-mgmt-address": "192.168.8.4",
        "service-function-dictionary": [
          {
            "name": "sf2",
            "sff-sf-data-plane-locator": {
              "sff-dpl-name": "vxgpe",
              "sf-dpl-name": "sf2-dpl"
            }
          }
        ],
        "service-node": "",
        "sff-data-plane-locator": [
          {
            "name": "vxgpe",
            "data-plane-locator": {
              "transport": "service-locator:vxlan-gpe",
              "ip": "192.168.8.4",
              "port": 6633
            },
            "service-function-forwarder-ovs:ovs-options": {
              "nshc4": "flow",
              "nshc3": "flow",
              "nsi": "flow",
              "nshc2": "flow",
              "nshc1": "flow",
              "exts": "gpe",
              "remote-ip": "flow",
              "key": "flow",
              "dst-port": "6633",
              "nsp": "flow"
            }
          }
        ],
        "service-function-forwarder-ovs:ovs-bridge": {
          "bridge-name": "br-int"
        }
      }
    ]
  }
}
```
### Create Services Chain

http://10.6.71.65:8181/restconf/config/service-function-chain:service-function-chains/
POST

```bash
{
  "service-function-chains": {
    "service-function-chain": [
      {
        "name": "firewall2-chain",
        "symmetric": false,
        "sfc-service-function": [
          {
            "name": "sf2",
            "type": "firewall"
          }
        ]
      }
    ]
  }
}
```
### Create Service Function Path

http://10.6.71.65:8181/restconf/config/service-function-path:service-function-paths/
POST

```bash
{
  "service-function-paths": {
    "service-function-path": [
      {
        "name": "Path-firewall2-chain",
        "service-path-hop": [
          {
            "hop-number": 0,
            "service-function-name": "sf2",
            "service-function-forwarder": "sff-192.168.8.4"
          }
        ],
        "symmetric": false,
        "service-chain-name": "firewall2-chain"
      }
    ]
  }
}
```
### Create Rendered Service Path


http://localhost:8181/restconf/operations/rendered-service-path:create-rendered-path
POST

```bash
{
    "input": {
        "name": "SFC-Path_rsp2",
        "parent-service-function-path": "Path-firewall2-chain",
        "symmetric": "false"
    }
}
```
### Check Rendered Service Path Configuration

http://10.6.71.65:8181/restconf/operational/rendered-service-path:rendered-service-paths/
GET

```bash
{
  "rendered-service-paths": {
    "rendered-service-path": [
      {
        "name": "SFC-Path_rsp2",
        "service-chain-name": "firewall2-chain",
        "transport-type": "service-locator:vxlan-gpe",
        "starting-index": 255,
        "path-id": 62,
        "parent-service-function-path": "Path-firewall2-chain",
        "rendered-service-path-hop": [
          {
            "hop-number": 0,
            "service-function-forwarder": "sff-192.168.8.4",
            "service-function-forwarder-locator": "vxgpe",
            "service-index": 255,
            "service-function-name": "sf2"
          }
        ]
      }
    ]
  }
}
```
### Create SFC classifier for HTTP and SSH

http://10.6.71.65:8181/restconf/config/ietf-access-control-list:access-lists/
POST

```bash
{
  "access-lists": {
    "acl": [
      {
        "acl-type": "ietf-access-control-list:ipv4-acl",
        "acl-name": "ssh-classifier",
        "access-list-entries": {
          "ace": [
            {
              "rule-name": "ssh-classifier",
              "matches": {
                "protocol": 6,
                "destination-port-range": {
                  "upper-port": 22,
                  "lower-port": 22
                },
                "source-port-range": {
                  "upper-port": 0,
                  "lower-port": 0
                }
              },
              "actions": {
                "netvirt-sfc-acl:rsp-name": "SFC-Path_rsp2"
              }
            }
          ]
        }
      },
      {
        "acl-type": "ietf-access-control-list:ipv4-acl",
        "acl-name": "http-classifier",
        "access-list-entries": {
          "ace": [
            {
              "rule-name": "http-classifier",
              "matches": {
                "protocol": 6,
                "destination-port-range": {
                  "upper-port": 80,
                  "lower-port": 80
                },
                "source-port-range": {
                  "upper-port": 0,
                  "lower-port": 0
                }
              },
              "actions": {
                "netvirt-sfc-acl:rsp-name": "SFC-Path_rsp2"
              }
            }
          ]
        }
      }
    ]
  }
}

```
now we can adjust the firewall:

```bash
sudo pkill python
sudo python vxlan_tool.py -i eth0 -d forward -v off -b  22
```

# Clean Up

##Delete Configuration ODL via API REST:
======================================
http://IP_Controller:8181/apidoc/explorer/index.html

http://10.6.71.65:8181/restconf/config/service-function:service-function/
DELETE
http://10.6.71.65:8181/restconf/config/service-function-forwarder:service-function-forwarders/
DELETE
http://10.6.71.65:8181/restconf/config/service-function-chain:service-function-chains/
DELETE
http://10.6.71.65:8181/restconf/config/service-function-path:service-function-paths/
DELETE
http://localhost:8181/restconf/operations/rendered-service-path:delete-rendered-path
POST
http://10.6.71.65:8181/restconf/config/ietf-access-control-list:access-lists/
DELETE



```bash

openstack server delete client server sf

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

