#
# Author:: Bryan W. Berry (<bryan.berry@gmail.com>)
# Cookbook Name:: java
# Resource:: ark
#
# Copyright 2011, Bryan w. Berry
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

actions :install, :remove

attribute :url, :regex => /^https?:\/\/.*(tar.gz|tgz|bin|zip)$/, :default => nil
attribute :mirrorlist, :kind_of => Array, :default => nil
attribute :checksum, :regex => /^[a-zA-Z0-9]{64}$/, :default => nil
attribute :app_home, :kind_of => String, :default => nil
attribute :app_home_mode, :kind_of => Integer, :default => 0755
attribute :bin_cmds, :kind_of => Array, :default => nil
attribute :owner, :default => "root"
attribute :default, :equal_to => [true, false], :default => true
attribute :alternatives_priority, :kind_of => Integer, :default => 1

# we have to set default for the supports attribute
# in initializer since it is a 'reserved' attribute name
def initialize(*args)
  super
  @action = :install
  @supports = {:report => true, :exception => true}
end
