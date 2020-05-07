#!/usr/bin/env ruby

require 'yaml'

if ARGV.length < 1
  abort "Need list of files"
end

inventory = {}

def inventory_host(v)
  ## v => hash of facts indexed by ansible fact name
  inv = {}

  inv["vcpus"] = v["ansible_processor_vcpus"]

  # Network interfaces
  inv["networks"] = {}
  # IPv4 list mapping to interfaces
  inv["ipv4"] = {}

  v["ansible_interfaces"].each do |iface|
    if_hash = v["ansible_#{iface}"]
    next if if_hash["features"]["loopback"].match(/on/) or not if_hash["active"]

    hash = if_hash.slice("type", "active", "device", "speed", "macaddress")
    hash.merge! if_hash["ipv4"] unless if_hash["ipv4"].nil?

    inv["networks"][iface] = hash

    inv["ipv4"][hash["address"]] = iface if hash.has_key?("address") and not hash["address"].nil?
  end

  inv["ipv4_default"] = v["ansible_default_ipv4"]

  inv["memory"] = v["ansible_memtotal_mb"] / 1024

  inv
end

ARGV.each do |arg|
  if not File.file?(arg)
    puts "'#{arg}' is not a regular file. Skipping."
    next
  end

  hostname = File.split(arg)[1].strip.downcase.delete_suffix(".yaml").delete_suffix(".yml")

  puts "Indexing host '#{hostname}'"

  inventory[hostname] = inventory_host(YAML.load_file(arg)["ansible_facts"])
end

File.open("inventory.yaml", "w") do |f|
  f.write(inventory.to_yaml)
end
