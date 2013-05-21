#
# Author:: Bryan W. Berry (<bryan.berry@gmail.com>)
# Cookbook Name:: java
# Recipe:: oracle_i386
#
# Copyright 2010-2011, Opscode, Inc.
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

java_home = node['java']["java_home"]

case node['java']['jdk_version']
when "6"
  tarball_url = node['java']['jdk']['6']['i586']['url']
  tarball_checksum = node['java']['jdk']['6']['i586']['checksum']
  bin_cmds = node['java']['jdk']['6']['bin_cmds']
when "7"
  tarball_url = node['java']['jdk']['7']['i586']['url']
  tarball_checksum = node['java']['jdk']['7']['i586']['checksum']
  bin_cmds = node['java']['jdk']['7']['bin_cmds']
end

ruby_block  "set-env-java-home" do
  block do
    ENV["JAVA_HOME"] = java_home
  end
  not_if { ENV["JAVA_HOME"] == java_home }
end

yum_package "glibc" do
  arch "i686"
  only_if { platform_family?( "rhel", "fedora" ) }
end

java_ark "jdk-alt" do
  url tarball_url
  checksum tarball_checksum
  app_home java_home 
  bin_cmds bin_cmds
  action :install
  default false
end
