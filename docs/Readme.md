# SFC Demo with Tacker

Inital created by <https://github.com/trozet/sfc-random>

## Neutron Network

Create at first a Neutron network

```bash
neutron net-create net_mgmt --provider:network_type=vxlan --provider:segmentation_id 1005
neutron subnet-create net_mgmt 123.123.123.0/24
```

## Glance SFC Image

```bash
curl -sLo /tmp/sfc_cloud.qcow2 https://www.dropbox.com/s/focu44sh52li7fz/sfc_cloud.qcow2 # Need create own
openstack image create sfc --disk-format qcow2 --public --file /tmp/sfc_cloud.qcow2
openstack flavor create custom --ram 1000 --disk 5 --public
```

## VNFD

Copy the file [VNFD](../sfc-files/test-vfnd.yaml) to the Host and create a VNFD:

```bash
tacker vnfd-create --vnfd-file ./test-vnfd.yaml
# if you want to delete it tacker vnfd-delete test-vnfd
tacker vnfd-list
```

Now we can deploy the VNF:

```bash
tacker vnf-create --name testVNF1 --vnfd-name test-vnfd
# if you want to delete it tacker vnf-delete testVNF1
# Check the status
heat stack-list
# List all VNFs
tacker vnf-list
```

Now go to login into the horizon UI (e.g. localhost:8002) with the `tacker` user. Go to Compute->Instances and select the VNF instance select Console and login as `root` `octopus` and configure the VNF (this should be automated, like cloud-init or something else):

```bash
service iptables stop
python ~/vxlan_tool/vxlan_tool.py -i eth0 -d forward -v on
```

## HTTP Server and client

### Download Cirros image

```bash
curl -sLo /tmp/cirros.img http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
openstack image create cirros --disk-format qcow2 --public --file /tmp/cirros.img
```

### Create instances

```bash
nova boot --flavor m1.small --image cirros --nic net-name=net_mgmt http_client
nova boot --flavor m1.small --image sfc --nic net-name=net_mgmt http_server
nova list
```

#### HTTP server

Stop iptables and start a simple Web server (same login as for the VNF)

```bash
service iptables stop
python -m SimpleHTTPServer 80
```

## SFC

```bash
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
