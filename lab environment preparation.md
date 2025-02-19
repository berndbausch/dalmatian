## Before running stack.sh

Add user ubuntu to group sudo.

Run visudo and configure nopassword for group sudo:

`%sudo   ALL=(ALL:ALL) NOPASSWD: ALL`

### In case your server accesses the internet via proxy:
```
$ export http_proxy=$HTTP_PROXY
$ export https_proxy=$HTTPS_PROXY
$ export no_proxy=$NO_PROXY,10.1.1.8
```
Also, add 10.1.1.8 to `NO_PROXY` in /etc/environment.
### Get the Dalmatian software from the Opendev git repo.
`$ git clone https://opendev.org/openstack/devstack.git -b stable/2024.2`

## stack.sh errors
- pip install fails when a proxy is required and the `*_proxy` variables are not set
- old version of setuptools was installed in `/opt/stack/data/venv` after a failed attempt to run stack.sh. This causes an error like this:

```"AttributeError: module 'setuptools.build_meta' has no attribute   'get_requires_for_build_editable'. Did you mean: 'get_requires_for_build_sdist'?"```

  Solution: delete `/opt/stack/data/venv` before running stack.sh again.

## Environment

### Ensure cloud-init doesn't mess with the network configuration
```
$ echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

### Prepare the devstack VM's networking
AFTER stack.sh:
  - remove IP address from ens160
  - replace netplan file with the following:
```
network:
  ethernets:
    ens160: {}
    br-ex:
      addresses:
      - 10.1.1.8/24
      - 172.24.4.1/24
      routes:
      - to: default
        via: 10.1.1.1
      nameservers:
        addresses: []
        search: []
  version: 2
```
### Copy the latest Fedora image
From `https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-UEFI-UKI-41-1.4.x86_64.qcow2` to `c:\Classfiles\05-glance`

### Add the following to ubuntu's .profile
```
# add /opt/stack/data/venv/bin to PATH
PATH=$PATH:/opt/stack/data/venv/bin
```

### Create second volume group
```
$ dd if=/dev/zero of=/opt/stack/data/stack-volumes-lvmdriver-2-backing-file bs=1M seek=30000 count=1
$ ls -lsh /opt/stack/data/
$ sudo losetup -a
$ sudo losetup /dev/loopX /opt/stack/data/stack-volumes-lvmdriver-2-backing-file
```
Set global filter in lvm.conf to a|loop.*|
```
$ sudo vgcreate stack-volumes-lvmdriver-2 /dev/loop8
```
Make it persistent by creating a new systemd service based on `stack-volumes-lvmdriver-1-backing-file.service`.
```
$ cd /etc/systemd/system
$ sudo cp stack-volumes-lvmdriver-{1,2}-backing-file.service
```
Edit the new unit file and replace 1 with 2 inside. Then:
```
$ sudo systemctl daemon-reload
$ sudo systemctl enable stack-volumes-lvmdriver-2-backing-file.service --now
```

### Double-check images
For some reason, stack.sh didn't download cirros at one point. If that happens, do it manually:
```
$ wget --progress=dot:giga -c http://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img -O /home/ubuntu/devstack/files/cirros-0.6.3-x86_64-disk.img
$ openstack image create --public --disk-format qcow2 --file /home/ubuntu/devstack/files/cirros-0.6.3-x86_64-disk.img cirros-0.6.3-x86_64-disk
```
### copy classfiles to ubuntu's $HOME

## Bugs

### Error in Horizon:
```
   Error: Unable to retrieve security group list. 
          Please try again later. 
   Details: 'Port' object has no attribute 'security_groups'
```
Indeed, the correct name of this port attribute is `security_group_ids`. Reported in https://bugs.launchpad.net/horizon/+bug/2089557.

To fix this, edit `/opt/stack/horizon/openstack_dashboard/api/neutron.py`. Change line 513 to 
```
sg_ids += p.security_group_ids
```
Restart the `apache2` service.

### Error when adding security group to server on command line
```
$ openstack server add security group server1 ssh
BadRequestException: 400: Client Error for url: http://192.168.1.201/compute/v2.1/servers/7f960925-2d67-4050-ae3d-53cee46ab442/action, Security group name cannot be empty
```
See https://bugs.launchpad.net/bugs/2089821. To fix it, open `/opt/stack/data/venv/lib/python3.10/site-packages/openstack/compute/v2/_proxy.py and replace `security_group.name` with `security_group.name or security_group.id,` in two lines:
```
    server.add_security_group(self, security_group.name or security_group.id,)
    server.remove_security_group(self, security_group.name or security_group.id,)  
```
