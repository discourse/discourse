# Author:: Bryan W. Berry (<bryan.berry@gmail.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: java
# Recipe:: openjdk
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

jdk_version = node['java']['jdk_version'].to_i
java_home = node['java']['java_home']
java_home_parent = ::File.dirname java_home
jdk_home = ""

pkgs = value_for_platform(
  ["centos","redhat","fedora","scientific","amazon","oracle"] => {
    "default" => ["java-1.#{jdk_version}.0-openjdk","java-1.#{jdk_version}.0-openjdk-devel"]
  },
  ["debian","ubuntu"] => {
    "default" => ["openjdk-#{jdk_version}-jdk","default-jre-headless"]
  },
  ["arch","freebsd"] => {
    "default" => ["openjdk#{jdk_version}"]
  },
  "default" => ["openjdk-#{jdk_version}-jdk"]
  )

# done by special request for rberger
ruby_block  "set-env-java-home" do
  block do
    ENV["JAVA_HOME"] = java_home
  end
  not_if { ENV["JAVA_HOME"] == java_home }
end

file "/etc/profile.d/jdk.sh" do
  content <<-EOS
    export JAVA_HOME=#{node['java']['java_home']}
  EOS
  mode 0755
end


if platform?("ubuntu","debian","redhat","centos","fedora","scientific","amazon","oracle")
  ruby_block "update-java-alternatives" do
    block do
      arch = node['kernel']['machine'] =~ /x86_64/ ? "x86_64" : "i386"
      arch = 'amd64' if arch == 'x86_64' && platform?("ubuntu") && node["platform_version"].to_f >= 12.04
      if platform?("ubuntu", "debian") and jdk_version == 6
        java_name = if node["platform_version"].to_f >= 11.10
          "java-1.6.0-openjdk"
        else
          "java-6-openjdk"
        end
        java_name += "-i386" if arch == "i386" && node['platform_version'].to_f >= 12.04
        Chef::ShellOut.new("update-java-alternatives","-s", java_name, :returns => [0,2]).run_command
      else
        # have to do this on ubuntu for version 7 because Ubuntu does
        # not currently set jdk 7 as the default jvm on installation
        require "fileutils"
        Chef::Log.debug("glob is #{java_home_parent}/java*#{jdk_version}*openjdk*#{arch}")
        jdk_home = Dir.glob("#{java_home_parent}/java*#{jdk_version}*openjdk*#{arch}").first
        Chef::Log.debug("jdk_home is #{jdk_home}")
        if jdk_home
          FileUtils.rm_f java_home if ::File.exists? java_home
          FileUtils.ln_sf jdk_home, java_home
        end

        cmd = Chef::ShellOut.new(
          %Q[ update-alternatives --install /usr/bin/java java #{java_home}/bin/java 1;
             update-alternatives --set java #{java_home}/bin/java  ]
          ).run_command
        unless cmd.exitstatus == 0 or  cmd.exitstatus == 2
          Chef::Application.fatal!("Failed to update-alternatives for openjdk!")
        end
      end
    end
    action :nothing
  end
end

pkgs.each do |pkg|
  package pkg do
    action :install
    notifies :create, "ruby_block[update-java-alternatives]", :immediately if platform?("ubuntu","debian","redhat","centos","fedora","scientific","amazon","oracle")
  end
end
