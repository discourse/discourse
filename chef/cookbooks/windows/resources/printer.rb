#
# Author:: Doug Ireton (<doug.ireton@nordstrom.com>)
# Cookbook Name:: windows
# Resource:: printer
#
# Copyright:: 2012, Nordstrom, Inc.
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
# See here for more info:
# http://msdn.microsoft.com/en-us/library/windows/desktop/aa394492(v=vs.85).aspx

require 'resolv'

actions :create, :delete

default_action :create

attribute :device_id, :kind_of => String, :name_attribute => true,
            :required => true
attribute :comment, :kind_of => String

attribute :default, :kind_of => [ TrueClass, FalseClass ], :default => false
attribute :driver_name, :kind_of => String, :required => true
attribute :location, :kind_of => String
attribute :shared, :kind_of => [ TrueClass, FalseClass ], :default => false
attribute :share_name, :kind_of => String

attribute :ipv4_address, :kind_of => String, :regex => Resolv::IPv4::Regex

attr_accessor :exists
