#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Provider:: feature_dism
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
  shell_out!("#{dism} /online /enable-feature /featurename:#{@new_resource.feature_name} /norestart", {:returns => [0,42,127]})
end

def remove_feature(name)
  shell_out!("#{dism} /online /disable-feature /featurename:#{@new_resource.feature_name} /norestart", {:returns => [0,42,127]})
end

def installed?
  @installed ||= begin
    cmd = shell_out("#{dism} /online /Get-Features", {:returns => [0,42,127]})
    cmd.stderr.empty? && (cmd.stdout =~  /^Feature Name : #{@new_resource.feature_name}.?$\n^State : Enabled.?$/i)
  end
end

private
# account for File System Redirector
# http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx
def dism
  @dism ||= begin
    locate_sysnative_cmd("dism.exe")
  end
end
