# Cheat Sheet for OVS

## Tools

OVS comes with different tools to configure and troubleshooting:

- ovs-vsctl : This tool is used to configure the ovs vswitch daemo (`ovs-vswitchd`) database also known as ovs-db
- ovs-ofctl : A command line tool for monitoring and administering OpenFlow switches
- ovs-dpctl : Used to administer Open vSwitch datapaths
- ovs−appctl : Used for querying and controlling Open vSwitch daemons

## ovs-vsctl

With this tool we can interact with the `OVSDB` to configure and view the OVS operations. For example we can do the following: Port configuration, bridge creation/deletion, bonding, VLAN tagging and many more.

Some useful commands:

- `ovs-vsctl –V`: Prints the version of the current switch and the DB schema.
- `ovs-vsctl`: Prints an overview of the configuration inside the OVSDB like the manager, bridges and according ports.
- `ovs-vsctl list-br`: Lists all configured bridges (only names).
- `ovs-vsctl list-ports <bridge>`: Lists all ports connected to a specific bridge.
- `ovs-vsctl port-to-br <port>`: Allows a reverse lookup and prints the name of bridge that contains `port`.
- `ovs-vsctl list interface`: Prints detailed information about all interfaces.

## ovs-ofctl

This tool is used to monitor and administrate OpenFlow switches.

Some useful commands:

- `ovs-ofctl -O OpenFlow13 show <bridge>`: Prints details about all ports connected to the bridge.
- `ovs-ofctl -O OpenFlow13 snoop <bridge>`: Show traffic from and to the bridge and prints it to the console.
- `ovs-ofctl -O OpenFlow13 dump-flows <bridge> <flow>`: Prints flow entries for the specified bridge. If you don't specify a flow all flow entries will be dumped otherwise only all matching flow entries will be printed.
- `ovs-ofctl -O OpenFlow13 dump-ports-desc <bridge>`: Prints details about the ports like speed, state and configuration.

ovs-ofctl dump-ports-desc

<bridge> : Prints port statistics. This will show detailed information about interfaces in this bridge, include the state, peer, and speed information. Very useful
ovs-ofctl dump-tables-desc <bridge> : Similar to above but prints the descriptions of tables belonging to the stated bridge.</bridge></bridge>

ovs-ofctl dump-ports-desc is useful for viewing port connectivity. This is useful in detecting errors in your NIC to bridge bonding.

Show all bridges

```bash
ovs-vsctl show
```

Show information (Ports) for a specific bridge like `br-int`

```bash
ovs-ofctl -O OpenFlow13 show br-int
# or alternative
ovs-ofctl -O OpenFlow13 dump-ports-desc br-int
```

Show statistics for all ports (or a specific one, the last argument is optional)

```bash
ovs-ofctl -O OpenFlow13 dump-ports br-int LOCAL
```

Get all flows for the bridge `br-int`

```bash
ovs-ofctl -O OpenFlow13 dump-flows br-int
```

# OpenStack

## Check DHCP

```bash
sudo apt install dhcpdump
sudo dhcpdump -i enp11s0f0
```

## Error Scheduling

If Hugepages not enables do the follwoing (<https://wiki.debian.org/Hugepages>)

```bash
# for 10GB with 2048 KB Page Size -> 10*1024*1024/2048
echo "5120" >> /etc/sysctl.conf
echo "vm.hugetlb_shm_group = $(cut -d: -f3 < <(getent group libvirt))" >> /etc/sysctl.conf
echo "KVM_HUGEPAGES=1" > /etc/default/qemu-kvm
reboot

grep Huge /proc/meminfo
# Lock max 10Gb
echo -e "soft memlock 10485760
hard memlock 10485760" >> /etc/security/limits.conf

sudo service libvirtd restart
```

or fix this by removeing the constraint:

```bash
nova flavor-key sfc_demo_flavor unset hw:mem_page_size
```

## Missing ODL entries

```bash
sudo ovs-ofctl -O OpenFlow13  add-flow br-ex "priority=0, action=normal"
sudo ovs-ofctl -O OpenFlow13  add-flow br-ex "dl_type=0x88cc, actions=CONTROLLER:65535"
```
