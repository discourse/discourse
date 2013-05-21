#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Resource:: package
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

actions :install, :remove

default_action :install

attribute :package_name, :kind_of => String, :name_attribute => true
attribute :source, :kind_of => String, :required => true
attribute :version, :kind_of => String
attribute :options, :kind_of => String
attribute :installer_type, :kind_of => Symbol, :default => nil, :equal_to => [:msi, :inno, :nsis, :wise, :installshield, :custom]
attribute :checksum, :kind_of => String
attribute :timeout, :kind_of => Integer, :default => 600
attribute :success_codes, :kind_of => Array, :default => [0, 42, 127]

# TODO

# add preseeding support
#attribute :response_file

# allow target dirtory of installation to be set
#attribute :target_dir

# Covers 0.10.8 and earlier
def initialize(*args)
  super
  @action = :install
end
