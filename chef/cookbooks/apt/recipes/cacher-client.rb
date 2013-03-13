#
# Cookbook Name:: apt
# Recipe:: cacher-client
#
# Copyright 2011, 2012 Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#remove Acquire::http::Proxy lines from /etc/apt/apt.conf since we use 01proxy
#these are leftover from preseed installs
execute 'Remove proxy from /etc/apt/apt.conf' do
  command "sed --in-place '/^Acquire::http::Proxy/d' /etc/apt/apt.conf"
  only_if "grep Acquire::http::Proxy /etc/apt/apt.conf"
end

servers = []
if node['apt'] && node['apt']['cacher_ipaddress']
  cacher = Chef::Node.new
  cacher.name(node['apt']['cacher_ipaddress'])
  cacher.ipaddress(node['apt']['cacher_ipaddress'])
  servers << cacher
end

unless Chef::Config[:solo]
  query = 'recipes:apt\:\:cacher-ng'
  query += " AND chef_environment:#{node.chef_environment}" if node['apt']['cacher-client']['restrict_environment']
  Chef::Log.debug("apt::cacher-client searching for '#{query}'")
  servers += search(:node, query)
end

if servers.length > 0
  Chef::Log.info("apt-cacher-ng server found on #{servers[0]}.")
  template '/etc/apt/apt.conf.d/01proxy' do
    source '01proxy.erb'
    owner 'root'
    group 'root'
    mode 00644
    variables(
      :proxy => servers[0]['ipaddress'],
      :port => node['apt']['cacher_port']
      )
  end.run_action(:create)
else
  Chef::Log.info('No apt-cacher-ng server found.')
  file '/etc/apt/apt.conf.d/01proxy' do
    action :delete
  end
end
