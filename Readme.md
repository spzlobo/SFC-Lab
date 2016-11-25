# Virtual deployment

Source: <http://artifacts.opnfv.org/sfc/colorado/2.0/docs/installationprocedure/index.html>

## Prerequisites

- SandyBridge compatible CPU with virtualization support
- capable to host 5 virtual cores (5 physical ones at least)
- 8-12 GBytes RAM for virtual hosts (controller, compute), 48GByte at least
- 128 GiBiBytes room on disk for each virtual host (controller, compute) + 64GiBiBytes for fuel master, 576 GiBiBytes at least
- Ubuntu Trusty Tahr - 14.04(.5) server operating system with at least ssh service selected at installation.
- Internet Connection (preferably http proxyless)

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

## Verification

```bash
ssh root@<external-vm> -L 8443:10.20.0.2:8443 # (admin/admin)
# chrome https://localhost:8443
ssh root@10.20.0.2 #(pwd: r00tme)
```

## Access OpenStack

### Web UI

```bash
ssh -A -t root@<external-vm> -L 8002:172.16.0.3:80 -L 8001:172.16.0.3:8000 -L 8181:172.16.0.3:8181 -L 6080:172.16.0.3:6080
# chrome localhost:8002 (admin/admin)
```

### terminal

```bash
ssh -A -t  root@<external-vm> ssh -A -t root@10.20.0.2 ssh -A -t root@10.20.0.3 #(pwd: r00tme)
# 6080:<heat-vm>:6080
source tackerc
nova list # return empty list
```

## Access OpenDaylight

Use Chrome: <http://localhost:8181/index.html> (admin/admin)

## SFC/VNF demo

[Readme](docs/Readme.md)

# TODO

- [ ] auto deploy demo
