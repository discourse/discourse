#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Resource:: feature
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

include Windows::Helper

actions :install, :remove

attribute :feature_name, :kind_of => String, :name_attribute => true

def initialize(name, run_context=nil)
  super
  @action = :install
  @provider = lookup_provider_constant(locate_default_provider)
end

private
def locate_default_provider
  if ::File.exists?(locate_sysnative_cmd('dism.exe'))
    :windows_feature_dism
  elsif ::File.exists?(locate_sysnative_cmd('servermanagercmd.exe'))
    :windows_feature_servermanagercmd
  end
end