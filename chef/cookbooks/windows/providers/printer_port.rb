#
# Author:: Doug Ireton (<doug.ireton@nordstrom.com>) 
# Cookbook Name:: windows
# Provider:: printer_port
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
      create_printer_port
    end
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete #{ @new_resource }") do
      delete_printer_port
    end
  else
    Chef::Log.info "#{ @current_resource } doesn't exist - can't delete."
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsPrinterPort.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.ipv4_address(@new_resource.ipv4_address)
  @current_resource.port_name(@new_resource.port_name || "IP_#{ @new_resource.ipv4_address }")

  if port_exists?(@current_resource.port_name)
    # TODO: Set @current_resource port properties from registry
    @current_resource.exists = true
  end
end


private

PORTS_REG_KEY = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\Ports\\'

def port_exists?(name)
  port_reg_key = PORTS_REG_KEY + name

  Chef::Log.debug "Checking to see if this reg key exists: '#{ port_reg_key }'"
  Registry.key_exists?(port_reg_key)
end


def create_printer_port

  port_name = new_resource.port_name || "IP_#{ new_resource.ipv4_address }"

  # create the printer port using PowerShell
  powershell "Creating printer port #{ new_resource.port_name }" do
    code <<-EOH

      Set-WmiInstance -class Win32_TCPIPPrinterPort `
        -EnableAllPrivileges `
        -Argument @{ HostAddress = "#{ new_resource.ipv4_address }";
                     Name        = "#{ port_name }";
                     Description = "#{ new_resource.port_description }";
                     PortNumber  = "#{ new_resource.port_number }";
                     Protocol    = "#{ new_resource.port_protocol }";
                     SNMPEnabled = "$#{ new_resource.snmp_enabled }";
                  }
    EOH
  end
end

def delete_printer_port

  port_name = new_resource.port_name || "IP_#{ new_resource.ipv4_address }"

  powershell "Deleting printer port: #{ new_resource.port_name }" do
    code <<-EOH
      $port = Get-WMIObject -class Win32_TCPIPPrinterPort -EnableAllPrivileges -Filter "name = '#{ port_name }'"
      $port.Delete()
    EOH
  end
end
