#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: chef_handlers
# Recipe:: default
#
# Copyright 2011, Opscode, Inc.
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

Chef::Log.info("Chef Handlers will be at: #{node['chef_handler']['handler_path']}")

remote_directory node['chef_handler']['handler_path'] do
  source 'handlers'
  # Just inherit permissions on Windows, don't try to set POSIX perms
  if node["platform"] != "windows"
    owner node['chef_handler']['root_user']
    group node['chef_handler']['root_group']
    mode "0755"
    recursive true
  end
  action :nothing
end.run_action(:create)
