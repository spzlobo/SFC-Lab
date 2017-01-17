# OpenDaylight and OpenStack

These are some notes of myself to understand the combination of ODL, OpenVSwitch and OpenStack better.

## NetVirt

Original Docs: <http://docs.opendaylight.org/en/stable-boron/user-guide/ovsdb-netvirt.html> + <http://flaviof.com/blog/work/how-to-odl-with-openstack-part1.html>

## OVS Tables

Table ID | Use
-------- | -------------------------------------------------------
0        | Classifier
10       | Director (Service Function Chaining (Classifier + SFF))
20       | Distributed ARP Responder(L2population)
30       | DNAT for inbound traffic (floating IP)
40       | Egress Acces-control (security groups)
50       | Distributed LBaaS
60       | Distributed Virtual Routing (DVR)
70       | Layer 3 forwarding/lookup service (e.q. ICMP)
80       | Layer 2 rewrite service
90       | Ingress Acces-control (security groups)
100      | SNAT for outbound traffic (floating IP)
110      | Layer2 mac,vlan based forwarding
150      | Service Function Chaining

## SFC with ODL (and OpenStack)

ODL uses the tables `10` and `150` for SFC rules.

action resubmit (port, table)

## Tunneling

OpenDaylight VXLAN tunneling with OpenVSwitch:

```bash
neutron net-show -F provider:segmentation_id sfc_demo_net
# convert decimal to hex
 echo "obase=16; 1005" | bc


ovs-ofctl -O OpenFlow13 dump-flows br-int | grep 0x3ed

# neutron dhcp-agent-list-hosting-net 5f1e4cc8-37e2-4bfb-b96f-ea1884121542
# sudo ip netns list | grep 5f1e4cc8-37e2-4bfb-b96f-ea1884121542
# ip netns exec qdhcp-5f1e4cc8-37e2-4bfb-b96f-ea1884121542 tcpdump port 67 or port 68 -lne
```

- 0x1->NXM_NX_REG0[] on same host
- 0x2->NXM_NX_REG0[] External

## Test SFC with multiple tenants
