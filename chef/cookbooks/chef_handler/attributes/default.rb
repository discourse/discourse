#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: chef_handlers
# Attribute:: default
#
# Copyright 2011-2013, Opscode, Inc
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

default["chef_handler"]["root_user"] = "root"

case platform
when "openbsd", "freebsd", "mac_os_x", "mac_os_x_server"
  default["chef_handler"]["root_group"] = "wheel"
else
  default["chef_handler"]["root_group"] = "root"
end

default["chef_handler"]["handler_path"] = "#{File.expand_path(File.join(Chef::Config[:file_cache_path], '..'))}/handlers"
