Description
===========

Provides a set of Windows-specific primitives (Chef resources) meant to aid in the creation of cookbooks/recipes targeting the Windows platform.

Requirements
============

Version 1.3.0+ of this cookbook requires Chef 0.10.10+.

Platform
--------

* Windows XP
* Windows Vista
* Windows Server 2003 R2
* Windows 7
* Windows Server 2008 (R1, R2)

The `windows_task` LWRP requires Windows Server 2008 due to its API usage.

Cookbooks
---------

The following cookbooks provided by Opscode are required as noted:

* chef_handler (`windows::reboot_handler` leverages the chef_handler LWRP)
* powershell - The Printer and Printer Port LWRP require Powershell.

**NOTE** We cannot specifically depend on Opscode's powershell,
  because powershell depends on this cookbook. Ensure that
  `recipe[powershell]` exists in the node's expanded run list so it
  gets downloaded where the printer LWRPs are used.

Attributes
==========

* `node['windows']['allow_pending_reboots']` - used to configure the `WindowsRebootHandler` (via the `windows::reboot_handler` recipe) to act on pending reboots. default is true (ie act on pending reboots).  The value of this attribute only has an effect if the `windows::reboot_handler` is in a node's run list.

Resource/Provider
=================

windows\_auto\_run
------------------

### Actions

- :create: Create an item to be run at login
- :remove: Remove an item that was previously setup to run at login

### Attribute Parameters

- :name: Name attribute. The name of the value to be stored in the registry
- :program: The program to be run at login
- :args: The arguments for the program

### Examples

    # Run BGInfo at login
    windows_auto_run 'BGINFO' do
      program "C:/Sysinternals/bginfo.exe"
      args "\"C:/Sysinternals/Config.bgi\" /NOLICPROMPT /TIMER:0"
      not_if { Registry.value_exists?(AUTO_RUN_KEY, 'BGINFO') }
      action :create
    end


windows\_batch
--------------

Execute a batch script using the cmd.exe interpreter (much like the script resources for bash, csh, powershell, perl, python and ruby). A temporary file is created and executed like other script resources, rather than run inline. By their nature, Script resources are not idempotent, as they are completely up to the user's imagination. Use the `not_if` or `only_if` meta parameters to guard the resource for idempotence.

### Actions

- :run: run the batch file

### Attribute Parameters

- command: name attribute. Name of the command to execute.
- code: quoted string of code to execute.
- creates: a file this command creates - if the file exists, the command will not be run.
- cwd: current working directory to run the command from.
- flags: command line flags to pass to the interpreter when invoking.
- user: A user name or user ID that we should change to before running this command.
- group: A group name or group ID that we should change to before running this command.

### Examples

    windows_batch "unzip_and_move_ruby" do
      code <<-EOH
      7z.exe x #{Chef::Config[:file_cache_path]}/ruby-1.8.7-p352-i386-mingw32.7z  -oC:\\source -r -y
      xcopy C:\\source\\ruby-1.8.7-p352-i386-mingw32 C:\\ruby /e /y
      EOH
    end

    windows_batch "echo some env vars" do
      code <<-EOH
      echo %TEMP%
      echo %SYSTEMDRIVE%
      echo %PATH%
      echo %WINDIR%
      EOH
    end

windows\_feature
----------------

Windows Roles and Features can be thought of as built-in operating system packages that ship with the OS.  A server role is a set of software programs that, when they are installed and properly configured, lets a computer perform a specific function for multiple users or other computers within a network.  A Role can have multiple Role Services that provide functionality to the Role.  Role services are software programs that provide the functionality of a role. Features are software programs that, although they are not directly parts of roles, can support or augment the functionality of one or more roles, or improve the functionality of the server, regardless of which roles are installed.  Collectively we refer to all of these attributes as 'features'.

This resource allows you to manage these 'features' in an unattended, idempotent way.

There are two providers for the `windows_features` which map into Microsoft's two major tools for managing roles/features: [Deployment Image Servicing and Management (DISM)](http://msdn.microsoft.com/en-us/library/dd371719(v=vs.85).aspx) and [Servermanagercmd](http://technet.microsoft.com/en-us/library/ee344834(WS.10).aspx) (The CLI for Server Manager).  As Servermanagercmd is deprecated, Chef will set the default provider to `Chef::Provider::WindowsFeature::DISM` if DISM is present on the system being configured.  The default provider will fall back to `Chef::Provider::WindowsFeature::ServerManagerCmd`.

For more information on Roles, Role Services and Features see the [Microsoft TechNet article on the topic](http://technet.microsoft.com/en-us/library/cc754923.aspx).  For a complete list of all features that are available on a node type either of the following commands at a command prompt:

    dism /online /Get-Features
    servermanagercmd -query

### Actions

- :install: install a Windows role/feature
- :remove: remove a Windows role/feature

### Attribute Parameters

- feature_name: name of the feature/role to install.  The same feature may have different names depending on the provider used (ie DHCPServer vs DHCP; DNS-Server-Full-Role vs DNS).

### Providers

- **Chef::Provider::WindowsFeature::DISM**: Uses Deployment Image Servicing and Management (DISM) to manage roles/features.
- **Chef::Provider::WindowsFeature::ServerManagerCmd**: Uses Server Manager to manage roles/features.

### Examples

    # enable the node as a DHCP Server
    windows_feature "DHCPServer" do
      action :install
    end

    # enable TFTP
    windows_feature "TFTP" do
      action :install
    end

    # disable Telnet client/server
    %w{ TelnetServer TelnetClient }.each do |feature|
      windows_feature feature do
        action :remove
      end
    end

windows\_package
----------------

Manage Windows application packages in an unattended, idempotent way.

The following application installers are currently supported:

* MSI packages
* InstallShield
* Wise InstallMaster
* Inno Setup
* Nullsoft Scriptable Install System

If the proper installer type is not passed into the resource's installer_type attribute, the provider will do it's best to identify the type by introspecting the installation package.  If the installation type cannot be properly identified the `:custom` value can be passed into the installer_type attribute along with the proper flags for silent/quiet installation (using the `options` attribute..see example below).

__PLEASE NOTE__ - For proper idempotence the resource's `package_name` should be the same as the 'DisplayName' registry value in the uninstallation data that is created during package installation.  The easiest way to definitively find the proper 'DisplayName' value is to install the package on a machine and search for the uninstall information under the following registry keys:

* `HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall`
* `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall`
* `HKEY_LOCAL_MACHINE\Software\Wow6464Node\Microsoft\Windows\CurrentVersion\Uninstall`

For maximum flexibility the `source` attribute supports both remote and local installation packages.

### Actions

- :install: install a package
- :remove: remove a package. The remove action is completely hit or miss as many application uninstallers do not support a full silent/quiet mode.

### Attribute Parameters

- package_name: name attribute. The 'DisplayName' of the application installation package.
- source: The source of the windows installer.  This can either be a URI or a local path.
- installer_type: They type of windows installation package. valid values are: :msi, :inno, :nsis, :wise, :installshield, :custom.  If this value is not provided, the provider will do it's best to identify the installer type through introspection of the file.
- checksum: useful if source is remote, the SHA-256 checksum of the file--if the local file matches the checksum, Chef will not download it
- options: Additional options to pass the underlying installation command
- timeout: set a timeout for the package download (default 600 seconds)
- version: The version number of this package, as indicated by the 'DisplayVersion' value in one of the 'Uninstall' registry keys.  If the given version number does equal the 'DisplayVersion' in the registry, the package will be installed.
- success_codes: set an array of possible successful installation
  return codes. Previously this was hardcoded, but certain MSIs may
  have a different return code, e.g. 3010 for reboot required. Must be
  an array, and defaults to `[0, 42, 127]`.

### Examples

    # install PuTTY (InnoSetup installer)
    windows_package "PuTTY version 0.60" do
      source "http://the.earth.li/~sgtatham/putty/latest/x86/putty-0.60-installer.exe"
      installer_type :inno
      action :install
    end

    # install 7-Zip (MSI installer)
    windows_package "7-Zip 9.20 (x64 edition)" do
      source "http://downloads.sourceforge.net/sevenzip/7z920-x64.msi"
      action :install
    end

    # install Notepad++ (Y U No Emacs?) using a local installer
    windows_package "Notepad++" do
      source "c:/installation_files/npp.5.9.2.Installer.exe"
      action :install
    end

    # install VLC for that Xvid (NSIS installer)
    windows_package "VLC media player 1.1.10" do
      source "http://superb-sea2.dl.sourceforge.net/project/vlc/1.1.10/win32/vlc-1.1.10-win32.exe"
      action :install
    end

    # install Firefox as custom installer and manually set the silent install flags
    windows_package "Mozilla Firefox 5.0 (x86 en-US)" do
      source "http://archive.mozilla.org/pub/mozilla.org/mozilla.org/firefox/releases/5.0/win32/en-US/Firefox%20Setup%205.0.exe"
      options "-ms"
      installer_type :custom
      action :install
    end

    # Google Chrome FTW (MSI installer)
    windows_package "Google Chrome" do
      source "https://dl-ssl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B806F36C0-CB54-4A84-A3F3-0CF8A86575E0%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dfalse/edgedl/chrome/install/GoogleChromeStandaloneEnterprise.msi"
      action :install
    end

    # remove Google Chrome (but why??)
    windows_package "Google Chrome" do
      action :remove
    end

    # remove 7-Zip
    windows_package "7-Zip 9.20 (x64 edition)" do
      action :remove
    end


windows\_printer\_port
----------------------

**Note** Include `recipe[powershell]` on the node's expanded run list
  to ensure the powershell cookbook is downloaded to avoid circular
  dependency.

Create and delete TCP/IPv4 printer ports.

### Actions

- :create: Create a TCIP/IPv4 printer port. This is the default action.
- :delete: Delete a TCIP/IPv4 printer port

### Attribute Parameters

- :ipv4_address: Name attribute. Required. IPv4 address, e.g. "10.0.24.34"
- :port_name: Port name. Optional. Defaults to "IP_" + :ipv4_address
- :port_number: Port number. Optional. Defaults to 9100.
- :port_description: Port description. Optional.
- :snmp_enabled: Boolean. Optional. Defaults to false.
- :port_protocol: Port protocol, 1 (RAW), or 2 (LPR). Optional. Defaults to 1.

### Examples

    # simplest example. Creates a TCP/IP printer port named "IP_10.4.64.37"
    # with all defaults
    windows_printer_port '10.4.64.37' do
    end

    # delete a printer port
    windows_printer_port '10.4.64.37' do
      action :delete
    end

    # delete a port with a custom port_name
    windows_printer_port '10.4.64.38' do
      port_name "My awesome port"
      action :delete
    end

    # Create a port with more options
    windows_printer_port '10.4.64.39' do
      port_name "My awesome port"
      snmp_enabled true
      port_protocol 2
    end


windows\_printer
----------------

**Note** Include `recipe[powershell]` on the node's expanded run list
  to ensure the powershell cookbook is downloaded to avoid circular
  dependency.

Create Windows printer. Note that this doesn't currently install a printer
driver. You must already have the driver installed on the system.

The Windows Printer LWRP will automatically create a TCP/IP printer port for you using the `ipv4_address` property. If you want more granular control over the printer port, just create it using the `windows_printer_port` LWRP before creating the printer.

### Actions

- :create: Create a new printer
- :delete: Delete a new printer

### Attribute Parameters

- :device_id: Name attribute. Required. Printer queue name, e.g. "HP LJ 5200 in fifth floor copy room"
- :comment: Optional string describing the printer queue.
- :default: Boolean. Optional. Defaults to false. Note that Windows sets the first printer defined to the default printer regardless of this setting.
- :driver_name: String. Required. Exact name of printer driver. Note that the printer driver must already be installed on the node.
- :location: Printer location, e.g. "Fifth floor copy room", or "US/NYC/Floor42/Room4207"
- :shared: Boolean. Defaults to false.
- :share_name: Printer share name.
- :ipv4_address: Printer IPv4 address, e.g. "10.4.64.23". You don't have to be able to ping the IP addresss to set it. Required.


### Examples

    # create a printer
    windows_printer 'HP LaserJet 5th Floor' do
      driver_name 'HP LaserJet 4100 Series PCL6'
      ipv4_address '10.4.64.38'
    end

    # delete a printer
    # Note: this doesn't delete the associated printer port.
    #   See `windows_printer_port` above for how to delete the port.
    windows_printer 'HP LaserJet 5th Floor' do
      action :delete
    end


windows\_reboot
---------------

Sets required data in the node's run_state to notify `WindowsRebootHandler` a reboot is requested.  If Chef run completes successfully a reboot will occur if the `WindowsRebootHandler` is properly registered as a report handler.  As an action of `:request` will cause a node to reboot every Chef run, this resource is usually notified by other resources...ie restart node after a package is installed (see example below).

### Actions

- :request: requests a reboot at completion of successful Cher run.  requires `WindowsRebootHandler` to be registered as a report handler.
- :cancel: remove reboot request from node.run_state.  this will cancel *ALL* previously requested reboots as this is a binary state.

### Attribute Parameters

- :timeout: Name attribute. timeout delay in seconds to wait before proceeding with the requested reboot. default is 60 seconds
- :reason: comment on the reason for the reboot. default is 'Opscode Chef initiated reboot'

### Examples

    # if the package installs, schedule a reboot at end of chef run
    windows_reboot 60 do
      reason 'cause chef said so'
      action :nothing
    end
    windows_package 'some_package' do
      action :install
      notifies :request, 'windows_reboot[60]'
    end

    # cancel the previously requested reboot
    windows_reboot 60 do
      action :cancel
    end

windows\_registry
-----------------

Creates and modifies Windows registry keys.

*Change in v1.3.0: The Win32 classes use `::Win32` to avoid namespace conflict with `Chef::Win32` (introduced in Chef 0.10.10).*

### Actions

- :create: create a new registry key with the provided values.
- :modify: modify an existing registry key with the provided values.
- :force_modify: modify an existing registry key with the provided values.  ensures the value is actually set by checking multiple times. useful for fighting race conditions where two processes are trying to set the same registry key.  This will be updated in the near future to use 'RegNotifyChangeKeyValue' which is exposed by the WinAPI and allows a process to register for notification on a registry key change.
- :remove: removes a value from an existing registry key

### Attribute Parameters

- key_name: name attribute. The registry key to create/modify.
- values: hash of the values to set under the registry key. The individual hash items will become respective 'Value name' => 'Value data' items in the registry key.
- type: Type of key to create, defaults to REG_SZ. Must be a symbol, see the overview below for valid values.

### Registry key types

- :binary: REG_BINARY
- :string: REG_SZ
- :multi_string: REG_MULTI_SZ
- :expand_string: REG_EXPAND_SZ
- :dword: REG_DWORD
- :dword_big_endian: REG_DWORD_BIG_ENDIAN
- :qword: REG_QWORD

### Examples

    # make the local windows proxy match the one set for Chef
    proxy = URI.parse(Chef::Config[:http_proxy])
    windows_registry 'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings' do
      values 'ProxyEnable' => 1, 'ProxyServer' => "#{proxy.host}:#{proxy.port}", 'ProxyOverride' => '<local>'
    end

    # enable Remote Desktop and poke the firewall hole
    windows_registry 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server' do
      values 'FdenyTSConnections' => 0
    end

    # Delete an item from the registry
    windows_registry 'HKCU\Software\Test' do
      #Key is the name of the value that you want to delete the value is always empty
      values 'ValueToDelete' => ''
      action :remove
    end

    # Add a REG_MULTI_SZ value to the registry
    windows_registry 'HKCU\Software\Test' do
      values 'MultiString' => ['line 1', 'line 2', 'line 3']
      type :multi_string
    end

### Library Methods

    Registry.value_exists?('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','BGINFO')
    Registry.key_exists?('HKLM\SOFTWARE\Microsoft')
    BgInfo = Registry.get_value('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','BGINFO')

windows\_path
-------------

### Actions

- :add: Add an item to the system path
- :remove: Remove an item from the system path

### Attribute Parameters

- :path: Name attribute. The name of the value to add to the system path

### Examples

    #Add Sysinternals to the system path
    windows_path 'C:\Sysinternals' do
      action :add
    end

    #Remove 7-Zip from the system path
    windows_path 'C:\7-Zip' do
      action :remove
    end

windows\_task
-------------

Creates, deletes or runs a Windows scheduled task. Requires Windows
Server 2008 due to API usage.

### Actions

- :create: creates a task
- :delete: deletes a task
- :run: runs a task
- :change: changes the un/pw or command of a task

### Attribute Parameters

- name: name attribute, The task name.
- command: The command the task will run.
- cwd: The directory the task will be run from.
- user: The user to run the task as. (requires password)
- password: The user's password. (requires user)
- run_level: Run with limited or highest privileges.
- frequency: Frequency with which to run the task. (hourly, daily, ect.)
- frequency_modifier: Multiple for frequency. (15 minutes, 2 days)

### Examples

    # Run Chef every 15 minutes
    windows_task "Chef client" do
      user "Administrator"
      password "$ecR3t"
      cwd "C:\chef\bin"
      command "chef-client -L C:\tmp\"
      run_level :highest
      frequency :minute
      frequency_modifier 15
    end

    # Update Chef Client task with new password and log location
    windows_task "Chef client" do
      user "Administrator"
      password "N3wPassW0Rd"
      cwd "C:\chef\bin"
      command "chef-client -L C:\chef\logs\"
      action :change
    end

    # Delete a taks named "old task"
    windows_task "old task" do
      action :delete
    end

windows\_zipfile
----------------

Most version of Windows do not ship with native cli utility for managing compressed files.  This resource provides a pure-ruby implementation for managing zip files. Be sure to use the `not_if` or `only_if` meta parameters to guard the resource for idempotence or action will be taken on the zip file every Chef run.

### Actions

- :unzip: unzip a compressed file

### Attribute Parameters

- path: name attribute. The path where files will be unzipped to.
- source: The source of the zip file. This can either be a URI or a local path.
- overwrite: force an overwrite of the files if the already exists.
- checksum: useful if source is remote, the SHA-256 checksum of the file--if the local file matches the checksum, Chef will not download it

### Examples

    # unzip a remote zip file locally
    windows_zipfile "c:/bin" do
      source "http://download.sysinternals.com/Files/SysinternalsSuite.zip"
      action :unzip
      not_if {::File.exists?("c:/bin/PsExec.exe")}
    end

    # unzip a local zipfile
    windows_zipfile "c:/the_codez" do
      source "c:/foo/baz/the_codez.zip"
      action :unzip
    end


Exception/Report Handlers
=========================

WindowsRebootHandler
--------------------

Required reboots are a necessary evil of configuring and managing Windows nodes.  This report handler (ie fires at the end of successful Chef runs) acts on requested (Chef initiated) or pending (as determined by the OS per configuration action we performed) reboots.  The `allow_pending_reboots` initialization argument should be set to false if you do not want the handler to automatically reboot a node if it has been determined a reboot is pending.  Reboots can still be requested explicitly via the `windows_reboot` LWRP.

## Initialization Arguments

- `allow_pending_reboots`: indicator on whether the handler should act on a the Window's 'pending reboot' state. default is true
- `timeout`: timeout delay in seconds to wait before proceeding with the reboot. default is 60 seconds
- `reason`:  comment on the reason for the reboot. default is 'Opscode Chef initiated reboot'

Usage
=====

Place an explicit dependency on this cookbook (using depends in the cookbook's metadata.rb) from any cookbook where you would like to use the Windows-specific resources/providers that ship with this cookbook.

    depends "windows"

default
-------

Convenience recipe that installs supporting gems for many of the resources/providers that ship with this cookbook.

*Change in v1.3.0: Uses chef_gem instead of gem_package to ensure gem installation in Chef 0.10.10.*

reboot\_handler
--------------

Leverages the `chef_handler` LWRP to register the `WindowsRebootHandler` report handler that ships as part of this cookbook. By default this handler is set to automatically act on pending reboots.  If you would like to change this behavior override `node['windows']['allow_pending_reboots']` and set the value to false.  For example:

    % cat roles/base.rb
    name "base"
    description "base role"
    override_attributes(
      "windows" => {
        "allow_pending_reboots" => false
      }
    )

This will still allow a reboot to be explicitly requested via the `windows_reboot` LWRP.

License and Author
==================

Author:: Seth Chisamore (<schisamo@opscode.com>)
Author:: Doug MacEachern (<dougm@vmware.com>)
Author:: Paul Morton (<pmorton@biaprotect.com>)
Author:: Doug Ireton (<doug.ireton@nordstrom.com>)

Copyright:: 2011, Opscode, Inc.
Copyright:: 2010, VMware, Inc.
Copyright:: 2011, Business Intelligence Associates, Inc
Copyright:: 2012, Nordstrom, Inc.


Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
