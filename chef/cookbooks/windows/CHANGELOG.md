## Future

* package preseeding/response_file support
* package installation location via a `target_dir` attribute.
* [COOK-666] `windows_package` should support CoApp packages
* windows_registry :force_modify action should use RegNotifyChangeKeyValue from WinAPI
* WindowsRebootHandler/`windows_reboot` LWRP should support kicking off subsequent chef run on reboot.

## v1.8.4:

* [COOK-2336] - MSI That requires reboot returns with RC 3010 and
  causes chef run failure
* [COOK-2368] - `version` attribute of the `windows_package` provider
  should be documented

## v1.8.2:

**Important**: Use powershell in nodes expanded run lists to ensure
  powershell is downloaded, as powershell has a dependency on this
  cookbook; v1.8.0 created a circular dependency.

* [COOK-2301] - windows 1.8.0 has circular dependency on powershell

## v1.8.0:

* [COOK-2126] - Add checksum attribute to windows_zipfile
* [COOK-2142] - Add printer and printer_port LWRPs
* [COOK-2149] - Chef::Log.debug Windows Package command line
* [COOK-2155] -`windows_package` does not send checksum to
  `cached_file` in `installer_type`

## v1.7.0:

* [COOK-1745] - allow for newer versions of rubyzip

## v1.6.0:

* [COOK-2048] - undefined method for Falseclass on task :change when
  action is :nothing (and task doesn't exist)
* [COOK-2049] - Add `windows_pagefile` resource

## v1.5.0:

* [COOK-1251] - Fix LWRP "NotImplementedError"
* [COOK-1921] - Task LWRP will return true for resource exists when no
  other scheduled tasks exist
* [COOK-1932] - Include :change functionality to windows task lwrp

## v1.4.0:

* [COOK-1571] - windows_package resource (with msi provider) does not
accept spaces in filename
* [COOK-1581] - Windows cookbook needs a scheduled tasks LWRP
* [COOK-1584] - `windows_registry` should support all registry types

## v1.3.4:

* [COOK-1173] - windows_registry throws Win32::Registry::Error for
  action :remove on a nonexistent key
* [COOK-1182] - windows package sets start window title instead of
  quoting a path
* [COOK-1476] - zipfile lwrp should support :zip action
* [COOK-1485] - package resource fails to perform install correctly
  when "source" contains quote
* [COOK-1519] - add action :remove for path lwrp

## v1.3.2:

* [COOK-1033] - remove the `libraries/ruby_19_patches.rb` file which
  causes havoc on non-Windows systems.
* [COOK-811] - add a timeout parameter attribute for `windows_package`

## v1.3.0:

* [COOK-1323] - Update for changes in Chef 0.10.10.
  - Setting file mode doesn't make sense on Windows (package provider
  - and reboot_handler recipe)
  - Prefix ::Win32 to avoid namespace collision with Chef::Win32
  - (registry_helper library)
  - Use chef_gem instead of gem_package so gems get installed correctly
    under the Ruby environment Chef runs in (reboot_handler recipe,
    zipfile provider)

## v1.2.12:

* [COOK-1037] - specify version for rubyzip gem
* [COOK-1007] - windows_feature does not work to remove features with
  dism
* [COOK-667] - shortcut resource + provider for Windows platforms

## v1.2.10

* [COOK-939] - add `type` parameter to `windows_registry` to allow binary registry keys.
* [COOK-940] - refactor logic so multiple values get created.

## v1.2.8

* FIX: Older Windows (Windows Server 2003) sometimes return 127 on successful forked commands
* FIX: `windows_package`, ensure we pass the WOW* registry redirection flags into reg.open

## v1.2.6

* patch to fix [CHEF-2684], Open4 is named Open3 in Ruby 1.9
* Ruby 1.9's Open3 returns 0 and 42 for successful commands
* retry keyword can only be used in a rescue block in Ruby 1.9

## v1.2.4

* windows_package - catch Win32::Registry::Error that pops up when searching certain keys

## v1.2.2

* combined numerous helper libarires for easier sharing across libaries/LWRPs
* renamed Chef::Provider::WindowsFeature::Base file to the more descriptive `feature_base.rb`
* refactored windows_path LWRP
  * :add action should MODIFY the the underlying ENV variable (vs CREATE)
  * deleted greedy :remove action until it could be made more idempotent
* added a windows_batch resource/provider for running batch scripts remotely

## v1.2.0

* [COOK-745] gracefully handle required server restarts on Windows platform
  * WindowsRebootHandler for requested and pending reboots
  * windows_reboot LWRP for requesting (receiving notifies) reboots
  * reboot_handler recipe for enabling WindowsRebootHandler as a report handler
* [COOK-714] Correct initialize misspelling
* RegistryHelper - new `get_values` method which returns all values for a particular key.

## v1.0.8

* [COOK-719] resource/provider for managing windows features
* [COOK-717] remove `windows_env_vars` resource as env resource exists in core chef
* new `Windows::Version` helper class
* refactored `Windows::Helper` mixin

## v1.0.6

* added `force_modify` action to `windows_registry` resource
* add `win_friendly_path` helper
* re-purpose default recipe to install useful supporting windows related gems

## v1.0.4

* [COOK-700] new resources and improvements to the `windows_registry` provider (thanks Paul Morton!)
  * Open the registry in the bitednes of the OS
  * Provide convenience methods to check if keys and values exit
  * Provide convenience method for reading registry values
  * NEW - `windows_auto_run` resource/provider
  * NEW - `windows_env_vars` resource/provider
  * NEW - `windows_path` resource/provider
* re-write of the windows_package logic for determining current installed packages
* new checksum attribute for windows_package resource...useful for remote packages

## v1.0.2:

* [COOK-647] account for Wow6432Node registry redirecter
* [COOK-656] begin/rescue on win32/registry

## 1.0.0:

* [COOK-612] initial release
