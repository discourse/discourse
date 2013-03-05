#
# Author:: Doug MacEachern (<dougm@vmware.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Author:: Paul Morton (<pmorton@biaprotect.com>)
# Cookbook Name:: windows
# Provider:: registry
#
# Copyright:: 2010, VMware, Inc.
# Copyright:: 2011, Opscode, Inc.
# Copyright:: 2011, Business Intelligence Associates, Inc
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
  require 'ruby-wmi'
end

module Windows
  module RegistryHelper

    @@native_registry_constant = ENV['PROCESSOR_ARCHITEW6432'] == 'AMD64' ? 0x0100 : 0x0200

    def get_hive_name(path)
      Chef::Log.debug("Resolving registry shortcuts to full names")

      reg_path = path.split("\\")
      hive_name = reg_path.shift

      hkey = {
        "HKLM" => "HKEY_LOCAL_MACHINE",
        "HKCU" => "HKEY_CURRENT_USER",
        "HKU"  => "HKEY_USERS"
      }[hive_name] || hive_name

      Chef::Log.debug("Hive resolved to #{hkey}")
      return hkey
    end

    def get_hive(path)

      Chef::Log.debug("Getting hive for #{path}")
      reg_path = path.split("\\")
      hive_name = reg_path.shift

      hkey = get_hive_name(path)

      hive = {
        "HKEY_LOCAL_MACHINE" => ::Win32::Registry::HKEY_LOCAL_MACHINE,
        "HKEY_USERS" => ::Win32::Registry::HKEY_USERS,
        "HKEY_CURRENT_USER" => ::Win32::Registry::HKEY_CURRENT_USER
        }[hkey]

      unless hive
        Chef::Application.fatal!("Unsupported registry hive '#{hive_name}'")
      end


      Chef::Log.debug("Registry hive resolved to #{hkey}")
      return hive
    end

    def unload_hive(path)
      hive = get_hive(path)
      if hive == ::Win32::Registry::HKEY_USERS
        reg_path = path.split("\\")
        priv = Chef::WindowsPrivileged.new
        begin
          priv.reg_unload_key(reg_path[1])
        rescue
        end
      end
    end

    def set_value(mode,path,values,type=nil)
      hive, reg_path, hive_name, root_key, hive_loaded = get_reg_path_info(path)
      key_name = reg_path.join("\\")

      Chef::Log.debug("Creating #{path}")

      if !key_exists?(path,true)
        create_key(path)
      end

      hive.send(mode, key_name, ::Win32::Registry::KEY_ALL_ACCESS | @@native_registry_constant) do |reg|
        changed_something = false
        values.each do |k,val|
          key = "#{k}" #wtf. avoid "can't modify frozen string" in win32/registry.rb
          cur_val = nil
          begin
            cur_val = reg[key]
          rescue
            #subkey does not exist (ok)
          end
          if cur_val != val
            Chef::Log.debug("setting #{key}=#{val}")
            
            if type.nil?
              type = :string
            end

            reg_type = {
              :binary => ::Win32::Registry::REG_BINARY,
              :string => ::Win32::Registry::REG_SZ,
              :multi_string => ::Win32::Registry::REG_MULTI_SZ,
              :expand_string => ::Win32::Registry::REG_EXPAND_SZ,
              :dword => ::Win32::Registry::REG_DWORD,
              :dword_big_endian => ::Win32::Registry::REG_DWORD_BIG_ENDIAN,
              :qword => ::Win32::Registry::REG_QWORD
            }[type]

            reg.write(key, reg_type, val)

            ensure_hive_unloaded(hive_loaded)

            changed_something = true
          end
        end
        return changed_something
      end
      return false
    end

    def get_value(path,value)
      hive, reg_path, hive_name, root_key, hive_loaded = get_reg_path_info(path)
      key = reg_path.join("\\")

      hive.open(key, ::Win32::Registry::KEY_ALL_ACCESS | @@native_registry_constant) do | reg |
        begin
          return reg[value]
        rescue
          return nil
        ensure
          ensure_hive_unloaded(hive_loaded)
        end
      end
    end

    def get_values(path)
      hive, reg_path, hive_name, root_key, hive_loaded = get_reg_path_info(path)
      key = reg_path.join("\\")
      hive.open(key, ::Win32::Registry::KEY_ALL_ACCESS | @@native_registry_constant) do | reg |
        values = []
        begin
        reg.each_value do |name, type, data|
          values << [name, type, data]
        end
        rescue
        ensure
          ensure_hive_unloaded(hive_loaded)
        end
        values
      end
    end

    def delete_value(path,values)
      hive, reg_path, hive_name, root_key, hive_loaded = get_reg_path_info(path)
      key = reg_path.join("\\")
      Chef::Log.debug("Deleting values in #{path}")
      hive.open(key, ::Win32::Registry::KEY_ALL_ACCESS | @@native_registry_constant) do | reg |
        values.each_key { |key|
          name = "#{key}"
          # Ensure delete operation is idempotent.
          if value_exists?(path, key)
            Chef::Log.debug("Deleting value #{name} in #{path}")
            reg.delete_value(name)
          else
            Chef::Log.debug("Value #{name} in #{path} does not exist, skipping.")
          end
        }
      end

    end

    def create_key(path)
      hive, reg_path, hive_name, root_key, hive_loaded = get_reg_path_info(path)
      key = reg_path.join("\\")
      Chef::Log.debug("Creating registry key #{path}")
      hive.create(key)
    end

    def value_exists?(path,value)
      if key_exists?(path,true)

        hive, reg_path, hive_name, root_key , hive_loaded = get_reg_path_info(path)
        key = reg_path.join("\\")

        Chef::Log.debug("Attempting to open #{key}");
        Chef::Log.debug("Native Constant #{@@native_registry_constant}")
        Chef::Log.debug("Hive #{hive}")

        hive.open(key, ::Win32::Registry::KEY_READ | @@native_registry_constant) do | reg |
          begin
            rtn_value = reg[value]
            return true
          rescue
            return false
          ensure
            ensure_hive_unloaded(hive_loaded)
          end
        end

      end
      return false
    end

    # TODO: Does not load user registry...
    def key_exists?(path, load_hive = false)
      if load_hive
        hive, reg_path, hive_name, root_key , hive_loaded = get_reg_path_info(path)
        key = reg_path.join("\\")
      else
        hive = get_hive(path)
        reg_path = path.split("\\")
        hive_name = reg_path.shift
        root_key = reg_path[0]
        key = reg_path.join("\\")
        hive_loaded = false
      end

      begin
        hive.open(key, ::Win32::Registry::Constants::KEY_READ | @@native_registry_constant )
        return true
      rescue
        return false
      ensure
        ensure_hive_unloaded(hive_loaded)
      end
    end

    def get_user_hive_location(sid)
      reg_key = "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\#{sid}"
      Chef::Log.debug("Looking for profile at #{reg_key}")
      if key_exists?(reg_key)
        return get_value(reg_key,'ProfileImagePath')
      else
        return nil
      end

    end

    def resolve_user_to_sid(username)
      begin
        sid = WMI::Win32_UserAccount.find(:first, :conditions => {:name => username}).sid
        Chef::Log.debug("Resolved user SID to #{sid}")
        return sid
      rescue
        return nil
      end
    end

    def hive_loaded?(path)
      hive = get_hive(path)
      reg_path = path.split("\\")
      hive_name = reg_path.shift
      user_hive = path[0]

      if is_user_hive?(hive)
        return key_exists?("#{hive_name}\\#{user_hive}")
      else
        return true
      end
    end

    def is_user_hive?(hive)
      if hive == ::Win32::Registry::HKEY_USERS
        return true
      else
        return true
      end
    end

    def get_reg_path_info(path)
      hive = get_hive(path)
      reg_path = path.split("\\")
      hive_name = reg_path.shift
      root_key = reg_path[0]
      hive_loaded = false

      if is_user_hive?(hive) && !key_exists?("#{hive_name}\\#{root_key}")
        reg_path, hive_loaded = load_user_hive(hive,reg_path,root_key)
        root_key = reg_path[0]
        Chef::Log.debug("Resolved user (#{path}) to (#{reg_path.join('/')})")
      end

      return hive, reg_path, hive_name, root_key, hive_loaded
    end

    def load_user_hive(hive,reg_path,user_hive)
      Chef::Log.debug("Reg Path #{reg_path}")
      # See if the hive is loaded. Logged in users will have a key that is named their SID
      # if the user has specified the a path by SID and the user is logged in, this function
      # should not be executed.
      if is_user_hive?(hive) && !key_exists?("HKU\\#{user_hive}")
        Chef::Log.debug("The user is not logged in and has not been specified by SID")
        sid = resolve_user_to_sid(user_hive)
        Chef::Log.debug("User SID resolved to (#{sid})")
        # Now that the user has been resolved to a SID, check and see if the hive exists.
        # If this exists by SID, the user is logged in and we should use that key.
        # TODO: Replace the username with the sid and send it back because the username
        # does not exist as the key location.
        load_reg = false
        if key_exists?("HKU\\#{sid}")
          reg_path[0] = sid #use the active profile (user is logged on)
          Chef::Log.debug("HKEY_USERS Mapped: #{user_hive} -> #{sid}")
        else
          Chef::Log.debug("User is not logged in")
          load_reg = true
        end

        # The user is not logged in, so we should load the registry from disk
        if load_reg
          profile_path = get_user_hive_location(sid)
          if profile_path != nil
            ntuser_dat = "#{profile_path}\\NTUSER.DAT"
            if ::File.exists?(ntuser_dat)
              priv = Chef::WindowsPrivileged.new
              if priv.reg_load_key(sid,ntuser_dat)
                Chef::Log.debug("RegLoadKey(#{sid}, #{user_hive}, #{ntuser_dat})")
                reg_path[0] = sid
              else
                Chef::Log.debug("Failed RegLoadKey(#{sid}, #{user_hive}, #{ntuser_dat})")
              end
            end
          end
        end
      end

      return reg_path, load_reg

    end

    private
    def ensure_hive_unloaded(hive_loaded=false)
      if(hive_loaded)
        Chef::Log.debug("Hive was loaded, we really should unload it")
        unload_hive(path)
      end
    end
  end
end

module Registry
  module_function
  extend Windows::RegistryHelper
end
