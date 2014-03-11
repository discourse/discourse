#
# Author:: Seth Vargo <sethvargo@gmail.com>
# Cookbook:: hostsfile
# Resource:: entry
#
# Copyright 2012-2013, Seth Vargo
# Copyright 2012, CustomInk, LCC
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

# List of all actions supported by the provider
actions :create, :create_if_missing, :append, :update, :remove

# Make create the default action
default_action :create

# Required attributes
attribute :ip_address, kind_of: String, name_attribute: true
attribute :hostname,   kind_of: String

# Optional attributes
attribute :aliases,  kind_of: Array
attribute :comment,  kind_of: String
attribute :priority, kind_of: Fixnum
attribute :unique,   kind_of: [TrueClass, FalseClass]
