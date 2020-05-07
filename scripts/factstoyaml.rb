#!/usr/bin/env ruby

require 'json'
require 'yaml'

if ARGV.length < 1
  abort "Need list of files"
end

ARGV.each do |arg|
  begin
    json = JSON.parse(File.read(arg))
  rescue => e
    puts "Reading #{arg} failed: #{e.message}"
    next
  end

  begin
    File.open("#{arg}.yaml", 'w') do |f|
      f.write(json.to_yaml)
    end
  rescue => e
    puts "Writing YAML for #{arg} failed: #{e.message}"
  end
end
