#!/usr/bin/env ruby

require 'json'

# Script to extact the /dev/sda disk's serial and to generate the
# corresponding commands to use that serial to set the root_device for
# the nodes in ironic

node_ids = JSON.parse(`openstack baremetal node list -c Name -c UUID --format json --provision-state available`)

nodes = {}
node_ids.each do |n|
  nodes[n["Name"]] = n["UUID"]
end

nodes.each do |n, u|
  json = JSON.parse(`openstack baremetal introspection data save #{n}`)
  disk = json["inventory"]["disks"].select { |d| d["name"] == "/dev/sda" }
  puts "openstack baremetal node set --property root_device='{\"serial\":\"#{disk[0]["serial"]}\"}' #{u}"
end
