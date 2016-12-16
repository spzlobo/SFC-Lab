# Virtual deployment of OPNFV SFC

## Prerequisites

- SandyBridge compatible CPU with virtualization support
- 5 Cores (physical)
- 48 GByte RAM
- 576 GiBiBytes Disk
- Ubuntu Trusty Tahr - 14.04(.5)
- Internet Connection

## Ansible

Copy the example files and adjust them to fit your needs:

```bash
cp ansible/inventory.example ansible/inventory
cp ansible/group_vars/all.example ansible/group_vars/all
```

Check if you can reach the fuel host:

```bash
ansible all -m ping -i ansible/inventory -u root
```

Deploy fuel on the host (and all prerequisites):

```bash
ansible-playbook -i ansible/inventory ansible/site.yml
```

Grab a big coffee :)

## Verification

```bash
ssh root@<external-vm> -L 8443:10.20.0.2:8443
ssh root@10.20.0.2 #(pwd: r00tme)
```

Use Chrome: localhost:8443 (admin/admin)

## Access OpenStack

### Web UI

```bash
ssh -A -t root@<external-vm> -L 8002:172.16.0.3:80 -L 8001:172.16.0.3:8000 -L 8181:172.16.0.3:8181 -L 6080:172.16.0.3:6080
```

Use Chrome: localhost:8002 (admin/admin)

### terminal

-> TODO set up pub key (how) ssh-copy-id -i ~/.ssh/id_rsa.pub root@external-vm>

```bash
ssh -A -t root@<external-vm> ssh -A -t root@10.20.0.2 ssh -A -t root@10.20.0.3 #(pwd: r00tme)
source tackerc
openstack service list
nova list # return empty list
```

## Access OpenDaylight

Use Chrome: <http://localhost:8181/index.html> (admin/admin)

## SFC testing

See [SFC testing](./sfc_testing.md)

## SFC/VNF demo

See [SFC demo](docs/sfc_demo.md)
