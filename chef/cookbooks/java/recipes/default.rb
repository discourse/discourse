#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: java
# Recipe:: default
#
# Copyright 2008-2011, Opscode, Inc.
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

if node['platform_family'] == "windows"
  include_recipe "java::windows"
else
  include_recipe "java::#{node['java']['install_flavor']}"
end

# Purge the deprecated Sun Java packages if remove_deprecated_packages is true
%w[sun-java6-jdk sun-java6-bin sun-java6-jre].each do |pkg|
  package pkg do
    action :purge
    only_if { node['java']['remove_deprecated_packages'] }
  end
end
