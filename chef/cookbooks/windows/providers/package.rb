#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Provider:: package
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

if RUBY_PLATFORM =~ /mswin|mingw32|windows/
  require 'win32/registry'
end

require 'chef/mixin/shell_out'
require 'chef/mixin/language'

include Chef::Mixin::ShellOut
include Windows::Helper

# the logic in all action methods mirror that of
# the Chef::Provider::Package which will make
# refactoring into core chef easy

action :install do
  # If we specified a version, and it's not the current version, move to the specified version
  if @new_resource.version != nil && @new_resource.version != @current_resource.version
    install_version = @new_resource.version
  # If it's not installed at all, install it
  elsif @current_resource.version == nil
    install_version = candidate_version
  end

  if install_version
    Chef::Log.info("Installing #{@new_resource} version #{install_version}")
    status = install_package(@new_resource.package_name, install_version)
    if status
      @new_resource.updated_by_last_action(true)
    end
  end
end

action :upgrade do
  if @current_resource.version != candidate_version
    orig_version = @current_resource.version || "uninstalled"
    Chef::Log.info("Upgrading #{@new_resource} version from #{orig_version} to #{candidate_version}")
    status = upgrade_package(@new_resource.package_name, candidate_version)
    if status
      @new_resource.updated_by_last_action(true)
    end
  end
end

action :remove do
  if removing_package?
    Chef::Log.info("Removing #{@new_resource}")
    remove_package(@current_resource.package_name, @new_resource.version)
    @new_resource.updated_by_last_action(true)
  else
  end
end

def removing_package?
  if @current_resource.version.nil?
    false # nothing to remove
  elsif @new_resource.version.nil?
    true # remove any version of a package
  elsif @new_resource.version == @current_resource.version
    true # remove the version we have
  else
    false # we don't have the version we want to remove
  end
end

def expand_options(options)
  options ? " #{options}" : ""
end

# these methods are the required overrides of
# a provider that extends from Chef::Provider::Package
# so refactoring into core Chef should be easy

def load_current_resource
  @current_resource = Chef::Resource::WindowsPackage.new(@new_resource.name)
  @current_resource.package_name(@new_resource.package_name)
  @current_resource.version(nil)

  unless current_installed_version.nil?
    @current_resource.version(current_installed_version)
  end

  @current_resource
end

def current_installed_version
  @current_installed_version ||= begin
    if installed_packages.include?(@new_resource.package_name)
      installed_packages[@new_resource.package_name][:version]
    end
  end
end

def candidate_version
  @candidate_version ||= begin
    @new_resource.version || 'latest'
  end
end

def install_package(name,version)
  Chef::Log.debug("Processing #{@new_resource} as a #{installer_type} installer.")
  install_args = [cached_file(@new_resource.source, @new_resource.checksum), expand_options(unattended_installation_flags), expand_options(@new_resource.options)]
  Chef::Log.info("Starting installation...this could take awhile.")
  Chef::Log.debug "Install command: #{ sprintf(install_command_template, *install_args) }"
  shell_out!(sprintf(install_command_template, *install_args), {:timeout => @new_resource.timeout, :returns => @new_resource.success_codes})
end

def remove_package(name, version)
  uninstall_string = installed_packages[@new_resource.package_name][:uninstall_string]
  Chef::Log.info("Registry provided uninstall string for #{@new_resource} is '#{uninstall_string}'")
  uninstall_command = begin
    if uninstall_string =~ /msiexec/i
      "#{uninstall_string} /qn"
    else
      uninstall_string.gsub!('"','')
      "start \"\" /wait /d\"#{::File.dirname(uninstall_string)}\" #{::File.basename(uninstall_string)}#{expand_options(@new_resource.options)} /S"
    end
  end
  Chef::Log.info("Removing #{@new_resource} with uninstall command '#{uninstall_command}'")
  shell_out!(uninstall_command, {:returns => @new_resource.success_codes})
end

private

def install_command_template
  case installer_type
  when :msi
    "msiexec%2$s \"%1$s\"%3$s"
  else
    "start \"\" /wait %1$s%2$s%3$s"
  end
end

def uninstall_command_template
  case installer_type
  when :msi
    "msiexec %2$s %1$s"
  else
    "start \"\" /wait /d%1$s %2$s %3$s"
  end
end

# http://unattended.sourceforge.net/installers.php
def unattended_installation_flags
  case installer_type
  when :msi
    "/qb /i"
  when :installshield
    "/s /sms"
  when :nsis
    "/S /NCRC"
  when :inno
    #"/sp- /silent /norestart"
    "/verysilent /norestart"
  when :wise
    "/s"
  else
  end
end

def installed_packages
  @installed_packages || begin
    installed_packages = {}
    # Computer\HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall
    installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE)) #rescue nil
    # 64-bit registry view
    # Computer\HKEY_LOCAL_MACHINE\Software\Wow6464Node\Microsoft\Windows\CurrentVersion\Uninstall
    installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE, (::Win32::Registry::Constants::KEY_READ | 0x0100))) #rescue nil
    # 32-bit registry view
    # Computer\HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
    installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE, (::Win32::Registry::Constants::KEY_READ | 0x0200))) #rescue nil
    # Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall
    installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_CURRENT_USER)) #rescue nil
    installed_packages
  end
end

def extract_installed_packages_from_key(hkey = ::Win32::Registry::HKEY_LOCAL_MACHINE, desired = ::Win32::Registry::Constants::KEY_READ)
  uninstall_subkey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
  packages = {}
  begin
    ::Win32::Registry.open(hkey, uninstall_subkey, desired) do |reg|
      reg.each_key do |key, wtime|
        begin
          k = reg.open(key, desired)
          display_name = k["DisplayName"] rescue nil
          version = k["DisplayVersion"] rescue "NO VERSION"
          uninstall_string = k["UninstallString"] rescue nil
          if display_name
            packages[display_name] = {:name => display_name,
                                      :version => version,
                                      :uninstall_string => uninstall_string}
          end
        rescue ::Win32::Registry::Error
        end
      end
    end
  rescue ::Win32::Registry::Error
  end
  packages
end

def installer_type
  @installer_type || begin
    if @new_resource.installer_type
      @new_resource.installer_type
    else
      basename = ::File.basename(cached_file(@new_resource.source, @new_resource.checksum))
      if basename.split(".").last == "msi" # Microsoft MSI
        :msi
      else
        # search the binary file for installer type
        contents = ::Kernel.open(::File.expand_path(cached_file(@new_resource.source)), "rb") {|io| io.read } # TODO limit data read in
        case contents
        when /inno/i # Inno Setup
          :inno
        when /wise/i # Wise InstallMaster
          :wise
        when /nsis/i # Nullsoft Scriptable Install System
          :nsis
        else
          # if file is named 'setup.exe' assume installshield
          if basename == "setup.exe"
            :installshield
          else
            raise Chef::Exceptions::AttributeNotFound, "installer_type could not be determined, please set manually"
          end
        end
      end
    end
  end
end
