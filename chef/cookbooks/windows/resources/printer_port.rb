#
# Author:: Doug Ireton (<doug.ireton@nordstrom.com>)
# Cookbook Name:: windows
# Resource:: printer_port
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

attribute :ipv4_address, :name_attribute => true, :kind_of => String,
            :required => true, :regex => Resolv::IPv4::Regex

attribute :port_name       , :kind_of => String
attribute :port_number     , :kind_of => Fixnum, :default => 9100
attribute :port_description, :kind_of => String
attribute :snmp_enabled    , :kind_of => [ TrueClass, FalseClass ],
            :default => false

attribute :port_protocol, :kind_of => Fixnum, :default => 1, :equal_to => [1, 2]

attr_accessor :exists
