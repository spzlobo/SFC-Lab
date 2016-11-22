# Virtual deployment

Source: <http://artifacts.opnfv.org/sfc/colorado/2.0/docs/installationprocedure/index.html>

## Prerequisites

- SandyBridge compatible CPU with virtualization support
- capable to host 5 virtual cores (5 physical ones at least)
- 8-12 GBytes RAM for virtual hosts (controller, compute), 48GByte at least
- 128 GiBiBytes room on disk for each virtual host (controller, compute) + 64GiBiBytes for fuel master, 576 GiBiBytes at least
- Ubuntu Trusty Tahr - 14.04(.5) server operating system with at least ssh service selected at installation.
- Internet Connection (preferably http proxyless)

## Required Packages

```bash
sudo apt-get -qq install -y git make curl libvirt-bin libpq-dev qemu-kvm \
                        qemu-system tightvncserver virt-manager sshpass \
                        fuseiso genisoimage blackbox xterm python-pip \
                        python-git python-dev python-oslo.config \
                        python-pip python-dev libffi-dev libxml2-dev \
                        libxslt1-dev libffi-dev libxml2-dev libxslt1-dev \
                        expect curl python-netaddr p7zip-full

sudo pip install --upgrade pip GitPython pyyaml netaddr paramiko lxml \
                 scp pycrypto ecdsa debtcollector netifaces enum
```

## Fuel

```bash
# git clone -b 'stable/colorado' ssh://<user>@gerrit.opnfv.org:29418/fuel
git clone -b 'stable/colorado' https://git.opnfv.org/fuel

wget http://artifacts.opnfv.org/fuel/colorado/opnfv-colorado.1.0.iso

mkdir fuel/deploy/config/labs/devel-pipeline/telematik-kit

cp -r fuel/deploy/config/labs/devel-pipeline/elx/* \
   fuel/deploy/config/labs/devel-pipeline/telematik-kit

vim fuel/deploy/config/labs/devel-pipeline/telematik-kit/fuel/config/dha.yaml

mkdir ~/fuel/deploy/images
```

Add at the bottom of dha.yaml

```yaml
disks:
 fuel: 64G
 controller: 128G
 compute: 128G

define_vms:
 controller:
   vcpu:
     value: 2
   memory:
     attribute_equlas:
       unit: KiB
     value: 12521472
   currentMemory:
     attribute_equlas:
       unit: KiB
     value: 12521472
 compute:
   vcpu:
     value: 2
   memory:
     attribute_equlas:
       unit: KiB
     value: 8388608
   currentMemory:
     attribute_equlas:
       unit: KiB
     value: 8388608
 fuel:
   vcpu:
     value: 2
   memory:
     attribute_equlas:
       unit: KiB
     value: 2097152
   currentMemory:
     attribute_equlas:
       unit: KiB
     value: 2097152
```

Start the Deployment

```bash
cd ~/fuel/ci
```

### No HA SFC

```bash
bash ./deploy.sh -b file://${HOME}/fuel/deploy/config/ -l devel-pipeline -p telematik-kit -s no-ha_odl-l2_sfc_heat_ceilometer_scenario.yaml -i file://${HOME}/fuel/opnfv-colorado.1.0.iso
```

### HA SFC

```bash
bash ./deploy.sh -b file://${HOME}/fuel/deploy/config/ -l devel-pipeline -p telematik-kit -s ha_odl-l2_sfc_heat_ceilometer_scenario.yaml -i file://${HOME}/fuel/opnfv-colorado.1.0.iso
```

# Debugging

If running as user `root` -> Error: `permission denied` as `root`

```
# vim /etc/libvirt/qemu.conf

sed -i '' 's/#user = "root"/user = "root"/g' /etc/libvirt/qemu.conf
sed -i '' 's/#group = "root"/group = "root"/g' /etc/libvirt/qemu.conf

service libvirt-bin restart
```
