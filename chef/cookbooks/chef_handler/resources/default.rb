#
# Author:: Seth Chisamore <schisamo@opscode.com>
# Cookbook Name:: chef_handler
# Resource:: default
#
# Copyright:: 2011-2013, Opscode, Inc <legal@opscode.com>
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

actions :enable, :disable

attribute :class_name, :kind_of => String, :name_attribute => true
attribute :source, :default => nil, :kind_of => String
attribute :arguments, :default => []
attribute :supports, :kind_of => Hash, :default => { :report => true, :exception => true }

# we have to set default for the supports attribute 
# in initializer since it is a 'reserved' attribute name
def initialize(*args)
  super
  @action = :enable
  @supports = { :report => true, :exception => true }
end
