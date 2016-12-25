# SFC Testing

Now ssh into the Jump host and execute the [functest](https://wiki.opnfv.org/display/sfc/Functest+SFC-ODL+-+Test+1):

```bash
# Set tag to running version e.q. colorado.3.0
TAG=colorado.3.0; docker run --rm --privileged=true --net=host -ti -e INSTALLER_TYPE=fuel -e INSTALLER_IP=10.20.0.2 -e DEPLOY_SCENARIO=os-odl_l2-sfc-noha -e CI_DEBUG=true --name sfc opnfv/functest:${TAG:-latest} /bin/bash

functest env prepare
. $creds

functest testcase run odl-sfc
```

## Fix Errors

Replace the two files: `/home/opnfv/repos/functest/testcases/features/sfc/compute_presetup_CI.bash` and `/home/opnfv/repos/functest/testcases/features/sfc/server_presetup_CI.bash` with the files located [here](../sfc-files/sfc-testcase). Now run `functest testcase run odl-sfc` again.

## Clean up

Now delete all instances created by the test:

```bash
tacker sfc-delete red
tacker sfc-delete blue

tacker device-delete testVNF1
tacker device-delete testVNF2

tacker device-template-delete test-vnfd1
tacker device-template-delete test-vnfd2

tacker vnfd-delete test-vnfd1
tacker vnfd-delete test-vnfd2

# Clean up floating ips
for i in $(neutron floatingip-list -c id -f value); do neutron floatingip-delete $i; done
# Clean up sec group
```
