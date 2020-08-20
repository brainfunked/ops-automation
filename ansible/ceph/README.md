# Setup Playbooks for RHCS Installation via ceph-ansible

These playbooks setup the Red Hat lab environment for a three + one node,
containerised RHCS deployment. The playbooks take care of subscription
management, package installation and ceph-ansible configuration. The playbooks
assume RHEL 7 or RHEL 8.

IMPORTANT: Use fqdn in the inventory.

Ensure that the variables are filled in in `group_vars/all.yml` and that the
inventory contains three groups:
- ceph: Nodes that will form the ceph cluster. For now, use three, though the
  playbooks don't actually count.
- ceph_ansible: Admin node from which ceph_ansible will be run.
- ceph_all: All the nodes from ceph and ceph_ansible groups.

The inventory will be populated as:

- mons: All `ceph` hosts.
- osds: All `ceph` hosts.
- grafana-server: `ceph_ansible` host.
- mgrs: All `ceph` hosts.
- mdss: All `ceph` hosts.

Edit `templates/ceph-ansible/group_vars/osds.yml` manually for any specific OSD
configuration, other than automatic.

