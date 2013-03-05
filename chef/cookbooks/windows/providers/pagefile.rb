#
# Author:: Kevin Moser (<kevin.moser@nordstrom.com>)
# Cookbook Name:: windows
# Provider:: pagefile
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

include Chef::Mixin::ShellOut
include Windows::Helper

action :set do
  pagefile = @new_resource.name
  initial_size = @new_resource.initial_size
  maximum_size = @new_resource.maximum_size
  system_managed = @new_resource.system_managed
  automatic_managed = @new_resource.automatic_managed
  updated = false

  if automatic_managed
    unless automatic_managed?
      set_automatic_managed
      updated = true
    end
  else
    if automatic_managed?
      unset_automatic_managed
      updated = true
    end

    # Check that the resource is not just trying to unset automatic managed, if it is do nothing more
    if (initial_size && maximum_size) || system_managed
      unless exists?(pagefile)
        create(pagefile)
      end

      if system_managed
        unless max_and_min_set?(pagefile, 0, 0)
          set_system_managed(pagefile)
          updated = true
        end
      else
        unless max_and_min_set?(pagefile, initial_size, maximum_size)
          set_custom_size(pagefile, initial_size, maximum_size)
          updated = true
        end
      end
    end
  end

  @new_resource.updated_by_last_action(updated)
end

action :delete do
  pagefile = @new_resource.name
  updated = false

  if exists?(pagefile)
    delete(pagefile)
    updated = true
  end

  @new_resource.updated_by_last_action(updated)
end


private
def exists?(pagefile)
  @exists ||= begin
    cmd = shell_out("#{wmic} pagefileset where SettingID=\"#{get_setting_id(pagefile)}\" list /format:list", {:returns => [0]})
    cmd.stderr.empty? && (cmd.stdout =~ /SettingID=#{get_setting_id(pagefile)}/i)
  end
end

def max_and_min_set?(pagefile, min, max)
  @max_and_min_set ||= begin
    cmd = shell_out("#{wmic} pagefileset where SettingID=\"#{get_setting_id(pagefile)}\" list /format:list", {:returns => [0]})
    cmd.stderr.empty? && (cmd.stdout =~ /InitialSize=#{min}/i) && (cmd.stdout =~ /MaximumSize=#{max}/i)
  end
end

def create(pagefile)
  Chef::Log.debug("Creating pagefile #{pagefile}")
  cmd = shell_out("#{wmic} pagefileset create name=\"#{win_friendly_path(pagefile)}\"")
  check_for_errors(cmd.stderr)
end

def delete(pagefile)
  Chef::Log.debug("Removing pagefile #{pagefile}")
  cmd = shell_out("#{wmic} pagefileset where SettingID=\"#{get_setting_id(pagefile)}\" delete")
  check_for_errors(cmd.stderr)
end

def automatic_managed?
  @automatic_managed ||= begin
    cmd = shell_out("#{wmic} computersystem where name=\"%computername%\" get AutomaticManagedPagefile /format:list")
    cmd.stderr.empty? && (cmd.stdout =~ /AutomaticManagedPagefile=TRUE/i)
  end
end

def set_automatic_managed
  Chef::Log.debug("Setting pagefile to Automatic Managed")
  cmd = shell_out("#{wmic} computersystem where name=\"%computername%\" set AutomaticManagedPagefile=True")
  check_for_errors(cmd.stderr)
end

def unset_automatic_managed
  Chef::Log.debug("Setting pagefile to User Managed")
  cmd = shell_out("#{wmic} computersystem where name=\"%computername%\" set AutomaticManagedPagefile=False")
  check_for_errors(cmd.stderr)
end

def set_custom_size(pagefile, min, max)
  Chef::Log.debug("Setting #{pagefile} to InitialSize=#{min} & MaximumSize=#{max}")
  cmd = shell_out("#{wmic} pagefileset where SettingID=\"#{get_setting_id(pagefile)}\" set InitialSize=#{min},MaximumSize=#{max}", {:returns => [0]})
  check_for_errors(cmd.stderr)
end

def set_system_managed(pagefile)
  Chef::Log.debug("Setting #{pagefile} to System Managed")
  cmd = shell_out("#{wmic} pagefileset where SettingID=\"#{get_setting_id(pagefile)}\" set InitialSize=0,MaximumSize=0", {:returns => [0]})
  check_for_errors(cmd.stderr)
end

def get_setting_id(pagefile)
  pagefile = win_friendly_path(pagefile)
  pagefile = pagefile.split("\\")
  "#{pagefile[1]} @ #{pagefile[0]}"
end

def check_for_errors(stderr)
  unless stderr.empty?
    Chef::Log.fatal(stderr)
  end
end

def wmic
  @wmic ||= begin
    locate_sysnative_cmd("wmic.exe")
  end
end