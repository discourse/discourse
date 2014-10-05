#
# Cookbook Name:: imagemagick
# Recipe:: default
#
# Copyright 2009, Opscode, Inc.
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

include_recipe "imagemagick"

dev_pkg = value_for_platform(
  ["redhat", "centos", "fedora", "amazon"] => { "default" => "ImageMagick-devel" },
  "debian" => { "default" => "libmagickwand-dev" },
  "ubuntu" => {
    "8.04" => "libmagick9-dev",
    "8.10" => "libmagick9-dev",
    "default" => "libmagickwand-dev"
  }
)

package dev_pkg
