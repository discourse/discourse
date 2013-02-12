Description
===========

Installs vim.

Requirements
============

## Platform:

* Ubuntu/Debian
* Red Hat/CentOS/Fedora/Scientific
* ArchLinux

Attributes
==========

* `node[:vim][:extra_packages]` - An array of extra packages related to vim to install (like plugins). Empty array by default.

Usage
=====

Put `recipe[vim]` in a run list, or `include_recipe 'vim'` to ensure that vim is installed on your systems.

If you would like to install additional vim plugin packages, include their package names in the `node[:vim][:extra_packages]` attribute. Verify that your operating sytem has the package available.

Changes
=======

## v1.0.2:

* Fixes COOK-598 (RHEL platforms support).

License and Author
==================

Author:: Joshua Timberman <joshua@opscode.com>

Copyright 2010, Opscode, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
