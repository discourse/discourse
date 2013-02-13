#
# Cookbook Name:: apt
# Recipe:: cacher-ng
#
# Copyright 2008-2012, Opscode, Inc.
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

package "apt-cacher-ng" do
  action :install
end

service "apt-cacher-ng" do
  supports :restart => true, :status => false
  action :enable
end

template "/etc/apt-cacher-ng/acng.conf" do
  source "acng.conf.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[apt-cacher-ng]"
end

# Reopen resource w/ start in case config issue causes startup to fail
service "apt-cacher-ng" do
  action :start
end

#this will help seed the proxy
include_recipe "apt::cacher-client"
