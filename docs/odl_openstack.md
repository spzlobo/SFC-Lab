# OpenDaylight and OpenStack

## NetVirt

Original Docs: <http://docs.opendaylight.org/en/stable-boron/user-guide/ovsdb-netvirt.html> + <http://flaviof.com/blog/work/how-to-odl-with-openstack-part1.html>

## OVS Tables

Table ID | Use
-------- | -------------------------------------------------------
0        | Classifier
10       | Director (Service Function Chaining (Classifier + SFF))
20       | Distributed ARP Responder(L2population)
30       | DNAT for inbound floating-ip traffic (floating IP)
40       | Egress Acces-control (security groups)
50       | Distributed LBaaS
60       | Distributed Virtual Routing (DVR)
70       | Layer 3 forwarding/lookup service (e.q. ICMP)
80       | Layer2 rewrite service
90       | Ingress Acces-control (security groups)
100      | SNAT for traffic accessing external network
110      | Layer2 mac,vlan based forwarding
150      | Service Function Chaining

## SFC with ODL (and OpenStack)

ODL uses the tables `10` and `150` for SFC rules.

action resubmit (port, table)
