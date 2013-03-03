#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Resource:: batch
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

actions :run

attribute :command, :kind_of => String, :name_attribute => true
attribute :cwd, :kind_of => String, :default => nil
attribute :code, :kind_of => String, :default => nil
attribute :user, :kind_of => [ String, Integer ], :default => nil
attribute :group, :kind_of => [ String, Integer ], :default => nil
attribute :creates, :kind_of => [ String ], :default => nil
attribute :flags, :kind_of => [ String ], :default => nil
attribute :returns, :kind_of => [Integer, Array], :default => 0

def initialize(name, run_context=nil)
  super
  @action = :run
  @command = name
end
