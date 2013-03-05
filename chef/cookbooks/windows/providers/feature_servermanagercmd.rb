#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Provider:: feature_servermanagercmd
#
# Copyright:: 2011, Opscode, Inc.
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

include Chef::Provider::WindowsFeature::Base
include Chef::Mixin::ShellOut
include Windows::Helper

def install_feature(name)
  shell_out!("#{servermanagercmd} -install #{@new_resource.feature_name}", {:returns => [0,42,127]})
end

def remove_feature(name)
  shell_out!("#{servermanagercmd} -remove #{@new_resource.feature_name}", {:returns => [0,42,127]})
end

def installed?
  @installed ||= begin
    cmd = shell_out("#{servermanagercmd} -query", {:returns => [0,42,127]})
    cmd.stderr.empty? && (cmd.stdout =~ /^\s*?\[X\]\s.+?\s\[#{@new_resource.feature_name}\]$/i)
  end
end

private
# account for File System Redirector
# http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx
def servermanagercmd
  @servermanagercmd ||= begin
    locate_sysnative_cmd("servermanagercmd.exe")
  end
end
