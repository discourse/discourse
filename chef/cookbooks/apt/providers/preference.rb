#
# Cookbook Name:: apt
# Provider:: preference
#
# Copyright 2010-2011, Opscode, Inc.
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

# Build preferences.d file contents
def build_pref(package_name, pin, pin_priority)
  preference_content = "Package: #{package_name}\nPin: #{pin}\nPin-Priority: #{pin_priority}\n"
end

action :add do
  new_resource.updated_by_last_action(false)

  preference = build_pref(new_resource.package_name,
                          new_resource.pin,
                          new_resource.pin_priority)

  preference_dir = directory "/etc/apt/preferences.d" do
    owner "root"
    group "root"
    mode 00755
    recursive true
    action :nothing
  end

  preference_file = file "/etc/apt/preferences.d/#{new_resource.name}" do
    owner "root"
    group "root"
    mode 00644
    content preference
    action :nothing
  end

  preference_dir.run_action(:create)
  # write out the preference file, replace it if it already exists
  preference_file.run_action(:create)
end

action :remove do
  if ::File.exists?("/etc/apt/preferences.d/#{new_resource.name}")
    Chef::Log.info "Un-pinning #{new_resource.name} from /etc/apt/preferences.d/"
    file "/etc/apt/preferences.d/#{new_resource.name}" do
      action :delete
    end
    new_resource.updated_by_last_action(true)
  end
end
