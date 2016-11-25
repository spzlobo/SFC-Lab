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

# TODO

- [ ] auto deploy setup
