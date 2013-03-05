#
# Author:: Doug MacEachern <dougm@vmware.com>
# Cookbook Name:: windows
# Provider:: shortcut
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

def load_current_resource
  require 'win32ole'

  @link = WIN32OLE.new("WScript.Shell").CreateShortcut(@new_resource.name)

  @current_resource = Chef::Resource::WindowsShortcut.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.target(@link.TargetPath)
  @current_resource.arguments(@link.Arguments)
  @current_resource.description(@link.Description)
  @current_resource.cwd(@link.WorkingDirectory)
end

# Check to see if the shorcut needs any changes
#
# === Returns
# <true>:: If a change is required
# <false>:: If the shorcuts are identical
def compare_shortcut
  [:target, :arguments, :description, :cwd].any? do |attr|
    !@new_resource.send(attr).nil? && @current_resource.send(attr) != @new_resource.send(attr)
  end
end

def action_create
  if compare_shortcut
    @link.TargetPath = @new_resource.target if @new_resource.target != nil
    @link.Arguments = @new_resource.arguments if @new_resource.arguments != nil
    @link.Description = @new_resource.description if @new_resource.description != nil
    @link.WorkingDirectory = @new_resource.cwd if @new_resource.cwd != nil
    #ignoring: WindowStyle, Hotkey, IconLocation
    @link.Save
    Chef::Log.info("Added #{@new_resource} shortcut")
    @updated = true
  end
end
