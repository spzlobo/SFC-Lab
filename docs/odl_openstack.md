# OpenDaylight and OpenStack

## NetVirt

Original Docs: <http://docs.opendaylight.org/en/stable-boron/user-guide/ovsdb-netvirt.html>

### Security groups

The current rules are applied on the basis of the following attributes: ingress/egress, protocol, port range, and prefix. In the pipeline, table 40 is used for egress ACL and table 90 for ingress ACL rules.
