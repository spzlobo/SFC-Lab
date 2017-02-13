# Create own service function

## Base OS

As a base OS we use [CoreOS](https://coreos.com/why/) which is an minimal OS designed to run containers. To use CoreOS with OpenStack the following steps are needed:

```bash
curl -sLo /tmp/coreos.img.bz2 https://stable.release.core-os.net/amd64-usr/current/coreos_production_openstack_image.img.bz2
bunzip2  /tmp/coreos.img.bz2

glance image-create --visibility=public --name=Container-Linux-stable --disk-format=qcow2 --container-format=bare --file=/tmp/coreos.img --progress
```

## VXLAN tool

For simplicity we put the [vxlan_tool](https://github.com/opendaylight/sfc/blob/master/sfc-test/nsh-tools/vxlan_tool.py) into a Docker Container.

```bash
docker build -t johscheuer/vxlan_tool:0.0.1 .
docker run -ti --network=host johscheuer/vxlan_tool:0.0.1 python3 vxlan_tool.py -i eth0 -d forward -v off -b 80
```
