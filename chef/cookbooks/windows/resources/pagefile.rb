#
# Author:: Kevin Moser (<kevin.moser@nordstrom.com>)
# Cookbook Name:: windows
# Resource:: pagefile
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

actions :set, :delete

attribute :name, :kind_of => String, :name_attribute => true
attribute :system_managed, :kind_of => [TrueClass, FalseClass]
attribute :automatic_managed, :kind_of => [TrueClass, FalseClass], :default => false
attribute :initial_size, :kind_of => Integer
attribute :maximum_size, :kind_of => Integer

default_action :set