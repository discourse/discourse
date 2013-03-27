#
# Author:: Doug MacEachern <dougm@vmware.com>
# Author:: Paul Morton (<pmorton@biaprotect.com>)
# Cookbook Name:: windows
# Library:: windows_privileged
#
# Copyright:: 2010, VMware, Inc.
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
  require 'windows/error'
  require 'windows/registry'
  require 'windows/process'
  require 'windows/security'
end

#helpers for Windows API calls that require privilege adjustments
class Chef
  class WindowsPrivileged
    if RUBY_PLATFORM =~ /mswin|mingw32|windows/
      include Windows::Error
      include Windows::Registry
      include Windows::Process
      include Windows::Security
    end
    #File -> Load Hive... in regedit.exe
    def reg_load_key(name, file)
      run(SE_BACKUP_NAME, SE_RESTORE_NAME) do
        rc = RegLoadKey(HKEY_USERS, "#{name}", file)
        if rc == ERROR_SUCCESS
          return true
        elsif rc == ERROR_SHARING_VIOLATION
          return false
        else
          raise get_last_error(rc)
        end
      end
    end

    #File -> Unload Hive... in regedit.exe
    def reg_unload_key(name)
      run(SE_BACKUP_NAME, SE_RESTORE_NAME) do
        rc = RegUnLoadKey(HKEY_USERS, "#{name}")
        if rc != ERROR_SUCCESS
          raise get_last_error(rc)
        end
      end
    end

    def run(*privileges)
      token = [0].pack('L')

      unless OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES|TOKEN_QUERY, token)
        raise get_last_error
      end
      token = token.unpack('L')[0]

      privileges.each do |name|
        unless adjust_privilege(token, name, SE_PRIVILEGE_ENABLED)
          raise get_last_error
        end
      end

      begin
        yield
      ensure #disable privs
        privileges.each do |name|
          adjust_privilege(token, name, 0)
        end
      end
    end

    def adjust_privilege(token, priv, attr=0)
      luid = [0,0].pack('Ll')
      if LookupPrivilegeValue(nil, priv, luid)
        new_state = [1, luid.unpack('Ll'), attr].flatten.pack('LLlL')
        AdjustTokenPrivileges(token, 0, new_state, new_state.size, 0, 0)
      end
    end
  end
end