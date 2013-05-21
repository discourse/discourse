#
# Author:: Doug MacEachern <dougm@vmware.com>
# Cookbook Name:: windows
# Resource:: shortcut
#
# Copyright:: 2010, VMware, Inc.
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

actions :create

default_action :create

attribute :name, :kind_of => String
attribute :target, :kind_of => String
attribute :arguments, :kind_of => String
attribute :description, :kind_of => String
attribute :cwd, :kind_of => String

# Covers 0.10.8 and earlier
def initialize(*args)
  super
  @action = :create
end
