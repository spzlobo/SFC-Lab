# Create own service function

## Base OS

As a base OS we use [RancherOS](http://rancher.com/rancher-os) which is an minimal OS (~44m MB) that runs completely in Docker. To use RancherOS in OpenStack the following steps are needed:

```bash
curl -sLo /tmp/rancheros.img https://github.com/rancher/os/releases/download/v0.7.1/rancheros-openstack.img
glance image-create --visibility=public --name=rancheros-v0.7.1 --disk-format=qcow2 --container-format=bare --file=/tmp/rancheros.img --progress
```

## VXLAN tool

For simplicity we put the [vxlan_tool](https://github.com/opendaylight/sfc/blob/master/sfc-test/nsh-tools/vxlan_tool.py) into a Docker Container.
