#
# Author:: Doug Ireton (<doug.ireton@nordstrom.com>) 
# Cookbook Name:: windows
# Provider:: printer
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

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - nothing to do."
  else
    converge_by("Create #{ @new_resource }") do
      create_printer
    end
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete #{ @new_resource }") do
      delete_printer
    end
  else
    Chef::Log.info "#{ @current_resource } doesn't exist - can't delete."
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsPrinter.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  if printer_exists?(@current_resource.name)
    # TODO: Set @current_resource printer properties from registry
    @current_resource.exists = true
  end
end


private

PRINTERS_REG_KEY = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Printers\\'

def printer_exists?(name)
  printer_reg_key = PRINTERS_REG_KEY + name
  Chef::Log.debug "Checking to see if this reg key exists: '#{ printer_reg_key }'"
  Registry.key_exists?(printer_reg_key)
end

def create_printer

  # Create the printer port first
  windows_printer_port new_resource.ipv4_address do
  end

  port_name = "IP_#{ new_resource.ipv4_address }"

  powershell "Creating printer: #{ new_resource.name }" do
    code <<-EOH

      Set-WmiInstance -class Win32_Printer `
        -EnableAllPrivileges `
        -Argument @{ DeviceID   = "#{ new_resource.device_id }";
                     Comment    = "#{ new_resource.comment }";
                     Default    = "$#{ new_resource.default }";
                     DriverName = "#{ new_resource.driver_name }";
                     Location   = "#{ new_resource.location }";
                     PortName   = "#{ port_name }";
                     Shared     = "$#{ new_resource.shared }";
                     ShareName  = "#{ new_resource.share_name }";
                  }
    EOH
  end
end

def delete_printer
  powershell "Deleting printer: #{ new_resource.name }" do
    code <<-EOH
      $printer = Get-WMIObject -class Win32_Printer -EnableAllPrivileges -Filter "name = '#{ new_resource.name }'"
      $printer.Delete()
    EOH
  end
end
