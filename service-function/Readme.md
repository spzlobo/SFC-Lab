# Create own service function

<https://www.packer.io/intro/getting-started/setup.html>

## Packer

Installation on Linux x64

```bash
apt-get install -y -qq unzip
curl -sLo /tmp/packer.zip https://releases.hashicorp.com/packer/0.12.1/packer_0.12.1_linux_amd64.zip
unzip /tmp/packer.zip
mv packer /usr/local/bin
# Validate Installation
packer --version
```

## VXLAN tool

Source: <https://github.com/opendaylight/sfc/blob/master/sfc-test/nsh-tools/vxlan_tool.py>
