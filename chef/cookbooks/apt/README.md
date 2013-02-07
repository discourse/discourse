Description
===========

This cookbook includes recipes to execute apt-get update to ensure the
local APT package cache is up to date. There are recipes for managing
the apt-cacher-ng caching proxy and proxy clients. It also includes a
LWRP for managing APT repositories in /etc/apt/sources.list.d as well as
an LWRP for pinning packages via /etc/apt/preferences.d.

Requirements
============

Version 1.8.2+ of this cookbook requires **Chef 10.16.4** or later.

If your Chef version is earlier than 10.16.4, use version 1.7.0 of
this cookbook.

See [CHEF-3493](http://tickets.opscode.com/browse/CHEF-3493) and
[this code comment](http://bit.ly/VgvCgf) for more information on this
requirement.

Platform
--------

* Debian
* Ubuntu

May work with or without modification on other Debian derivatives.

Recipes
=======

default
-------

This recipe installs the `update-notifier-common` package to provide
the timestamp file used to only run `apt-get update` if the cache is
more than one day old.

This recipe should appear first in the run list of Debian or Ubuntu
nodes to ensure that the package cache is up to date before managing
any `package` resources with Chef.

This recipe also sets up a local cache directory for preseeding packages.

cacher-ng
---------

Installs the `apt-cacher-ng` package and service so the system can
provide APT caching. You can check the usage report at
http://{hostname}:3142/acng-report.html. The `cacher-ng` recipe
includes the `cacher-client` recipe, so it helps seed itself.

cacher-client
-------------
Configures the node to use the `apt-cacher-ng` server as a client. If you
want to restrict your node to using the `apt-cacher-ng` server in your
Environment, set `['apt']['cacher-client']['restrict_environment']` to `true`.
To use a cacher server (or standard proxy server) not available via search
set the atttribute `['apt']['cacher-ipaddress']` and for a custom port
set `['apt']['cacher_port']`

Resources/Providers
===================

Managing repositories
---------------------

This LWRP provides an easy way to manage additional APT repositories.
Adding a new repository will notify running the `execute[apt-get-update]`
resource immediately.

# Actions

- :add: creates a repository file and builds the repository listing
- :remove: removes the repository file

# Attribute Parameters

- repo_name: name attribute. The name of the channel to discover
- uri: the base of the Debian distribution
- distribution: this is usually your release's codename...ie something
  like `karmic`, `lucid` or `maverick`
- components: package groupings..when it doubt use `main`
- arch: constrain package to a particular arch like `i386`, `amd64` or
  even `armhf` or `powerpc`. Defaults to nil.
- deb_src: whether or not to add the repository as a source repo as
  well - value can be `true` or `false`, default `false`.
- keyserver: the GPG keyserver where the key for the repo should be retrieved
- key: if a `keyserver` is provided, this is assumed to be the
  fingerprint, otherwise it can be either the URI to the GPG key for
  the repo, or a cookbook_file.
- cookbook: if key should be a cookbook_file, specify a cookbook where
  the key is located for files/default. Defaults to nil, so it will
  use the cookbook where the resource is used.

# Examples

    # add the Zenoss repo
    apt_repository "zenoss" do
      uri "http://dev.zenoss.org/deb"
      components ["main","stable"]
    end

    # add the Nginx PPA; grab key from keyserver
    apt_repository "nginx-php" do
      uri "http://ppa.launchpad.net/nginx/php5/ubuntu"
      distribution node['lsb']['codename']
      components ["main"]
      keyserver "keyserver.ubuntu.com"
      key "C300EE8C"
    end

    # add the Nginx PPA; grab key from keyserver, also add source repo
    apt_repository "nginx-php" do
      uri "http://ppa.launchpad.net/nginx/php5/ubuntu"
      distribution node['lsb']['codename']
      components ["main"]
      keyserver "keyserver.ubuntu.com"
      key "C300EE8C"
      deb_src true
    end

    # add the Cloudkick Repo
    apt_repository "cloudkick" do
      uri "http://packages.cloudkick.com/ubuntu"
      distribution node['lsb']['codename']
      components ["main"]
      key "http://packages.cloudkick.com/cloudkick.packages.key"
    end

    # add the Cloudkick Repo with the key downloaded in the cookbook
    apt_repository "cloudkick" do
      uri "http://packages.cloudkick.com/ubuntu"
      distribution node['lsb']['codename']
      components ["main"]
      key "cloudkick.packages.key"
    end

    # add the Cloudera Repo of CDH4 packages for Ubuntu 12.04 on AMD64
    apt_repository "cloudera" do
      uri "http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh"
      arch "amd64"
      distribution "precise-cdh4"
      components ["contrib"]
      key "http://archive.cloudera.com/debian/archive.key"
    end

    # remove Zenoss repo
    apt_repository "zenoss" do
      action :remove
    end

Pinning packages
----------------

This LWRP provides an easy way to pin packages in /etc/apt/preferences.d.
Although apt-pinning is quite helpful from time to time please note that Debian
does not encourage its use without thorough consideration.

Further information regarding apt-pinning is available via
http://wiki.debian.org/AptPreferences.

# Actions

- :add: creates a preferences file under /etc/apt/preferences.d
- :remove: Removes the file, therefore unpin the package

# Attribute Parameters

- package_name: name attribute. The name of the package
- pin: The package version/repository to pin
- pin_priority: The pinning priority aka "the highest package version wins"

# Examples

    # Pin libmysqlclient16 to version 5.1.49-3
    apt_preference "libmysqlclient16" do
      pin "version 5.1.49-3"
      pin_priority "700"
    end

    # Unpin libmysqlclient16
    apt_preference "libmysqlclient16" do
      action :remove
    end

Usage
=====

Put `recipe[apt]` first in the run list. If you have other recipes
that you want to use to configure how apt behaves, like new sources,
notify the execute resource to run, e.g.:

    template "/etc/apt/sources.list.d/my_apt_sources.list" do
      notifies :run, resources(:execute => "apt-get update"), :immediately
    end

The above will run during execution phase since it is a normal
template resource, and should appear before other package resources
that need the sources in the template.

Put `recipe[apt::cacher-ng]` in the run_list for a server to provide
APT caching and add `recipe[apt::cacher-client]` on the rest of the
Debian-based nodes to take advantage of the caching server.

If you want to cleanup unused packages, there is also the `apt-get autoclean`
and `apt-get autoremove` resources provided for automated cleanup.

License and Author
==================

Author:: Joshua Timberman (<joshua@opscode.com>)
Author:: Matt Ray (<matt@opscode.com>)
Author:: Seth Chisamore (<schisamo@opscode.com>)

Copyright 2009-2012 Opscode, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
