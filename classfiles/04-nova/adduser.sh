KEY=${1:-mykey}
echo "using key '$KEY'"

cat <<EOF >adduser.yaml
#cloud-config
# Add groups cloud-users and fred to the instance
# Group fred is required because user fred requires the existence of this group
groups:
  - cloud-users
  - fred

# Add users to the system. Users are added after groups are added.
users:
  - default
  - name: fred
    gecos: Fred Flintstone
    primary-group: fred
    groups: cloud-users
    expiredate: 2019-12-31
    ssh-authorized-keys:
    - $(openstack keypair show --public-key $KEY)
EOF

