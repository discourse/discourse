Description
===========

Installs a Java. Uses OpenJDK by default but supports installation of Oracle's JDK.

This cookbook contains the `java_ark` LWPR which has been deprecated
in favor of [ark](https://github.com/opscode-cookbooks/ark).

**IMPORTANT NOTE**

As of 26 March 2012 you can no longer directly download
the JDK from Oracle's website without using a special cookie. This cookbook uses
that cookie to download the oracle recipe on your behalf, but . . .

the java::oracle recipe forces you to set either override
the `node['java']['oracle']['accept_oracle_download_terms']` to true or set up a
private repository accessible by HTTP.

Example

### override the `accept_oracle_download_terms`

roles/base.rb
This cookbook also provides the `java_ark` LWRP which other java
cookbooks can use to install java-related applications from binary
packages.

    default_attributes(
      :java => {
         :oracle => {
           "accept_oracle_download_terms" => true
         }
       }
    )

You are most encouraged to voice your complaints to Oracle and/or
switch to OpenJDK.

Requirements
============

Platform
--------

* Debian, Ubuntu
* CentOS, Red Hat, Fedora, Scientific, Amazon
* ArchLinux
* FreeBSD
* Windows

Attributes
==========

See `attributes/default.rb` for default values.

* `node["java"]["install_flavor"]` - Flavor of JVM you would like installed (`oracle` or
`openjdk`), default `openjdk`.
* `node['java']['java_home']` - Default location of the "`$JAVA_HOME`".
* `node['java']['tarball']` - Name of the tarball to retrieve from your corporate
repository default `jdk1.6.0_29_i386.tar.gz`
* `node['java']['tarball_checksum']` - Checksum for the tarball, if you use a different
tarball, you also need to create a new sha256 checksum
* `node['java']['jdk']` - Version and architecture specific attributes for setting the
URL on Oracle's site for the JDK, and the checksum of the .tar.gz.
* `node['java']['remove_deprecated_packages']` - Removes the now deprecated Ubuntu JDK
packages from the system, default `false`
* `node['java']['oracle']['accept_oracle_download_terms']` - Indicates that you accept
  Oracle's EULA
* `node['java']['windows']['url']` - The internal location of your java install for windows
* `node['java']['windows']['package_name']` - The package name used by windows_package to
  check in the registry to determine if the install has already been run

Recipes
=======

default
-------

Include the default recipe in a run list, to get `java`.  By default
the `openjdk` flavor of Java is installed, but this can be changed by
using the `install_flavor` attribute. If the platform is windows it 
will include the windows recipe instead.

OpenJDK is the default because of licensing changes made upstream by
Oracle. See notes on the `oracle` recipe below.

openjdk
-------

This recipe installs the `openjdk` flavor of Java.

oracle
------

This recipe installs the `oracle` flavor of Java. This recipe does not
use distribution packages as Oracle changed the licensing terms with
JDK 1.6u27 and prohibited the practice for both the debian and EL worlds.

For both debian and centos/rhel, this recipe pulls the binary
distribution from the Oracle website, and installs it in the default
JAVA_HOME for each distribution. For debian/ubuntu, this is
/usr/lib/jvm/default-java. For Centos/RHEL, this is /usr/lib/jvm/java

After putting the binaries in place, the oracle recipe updates
/usr/bin/java to point to the installed JDK using the
`update-alternatives` script

oracle_i386
-----------

This recipe installs the 32-bit Java virtual machine without setting
it as the default. This can be useful if you have applications on the
same machine that require different versions of the JVM.

windows
-------

Because there is no easy way to pull the java msi off oracle's site, 
this recipe requires you to host it internally on your own http repo.

Resources/Providers
===================

This cookbook contains the `java_ark` LWPR which has been deprecated
in favor of [ark](https://github.com/opscode-cookbooks/ark).

By default, the extracted directory is extracted to
`app_root/extracted_dir_name` and symlinked to `app_root/default`

# Actions

- `:install`: extracts the tarball and makes necessary symlinks
- `:remove`: removes the tarball and run update-alternatives for all
  symlinked `bin_cmds`

# Attribute Parameters

- `url`: path to tarball, .tar.gz, .bin (oracle-specific), and .zip
  currently supported
- `checksum`: sha256 checksum, not used for security but avoid
  redownloading the archive on each chef-client run
- `app_home`: the default for installations of this type of
  application, for example, `/usr/lib/tomcat/default`. If your
  application is not set to the default, it will be placed at the same
  level in the directory hierarchy but the directory name will be
   `app_root/extracted_directory_name + "_alt"`
- `app_home_mode`: file mode for app_home, is an integer
- `bin_cmds`: array of binary commands that should be symlinked to
  /usr/bin, examples are mvn, java, javac, etc. These cmds must be in
  the bin/ subdirectory of the extracted folder. Will be ignored if this
  java_ark is not the default
- `owner`: owner of extracted directory, set to "root" by default
- `default`: whether this the default installation of this package,
  boolean true or false


# Examples

    # install jdk6 from Oracle
    java_ark "jdk" do
        url 'http://download.oracle.com/otn-pub/java/jdk/6u29-b11/jdk-6u29-linux-x64.bin'
        checksum  'a8603fa62045ce2164b26f7c04859cd548ffe0e33bfc979d9fa73df42e3b3365'
        app_home '/usr/local/java/default'
        bin_cmds ["java", "javac"]
        action :install
    end


Usage
=====

Simply include the `java` recipe where ever you would like Java installed.

To install Oracle flavored Java on Debian or Ubuntu override the `node['java']['install_flavor']` attribute with in role:

    name "java"
    description "Install Oracle Java on Ubuntu"
    override_attributes(
      "java" => {
        "install_flavor" => "oracle"
      }
    )
    run_list(
      "recipe[java]"
    )

Development
===========

This cookbook uses
[test-kitchen](https://github.com/opscode/test-kitchen) for
integration tests. Pull requests should pass existing tests in
files/default/tests/minitest-handler. Additional tests are always welcome.

License and Author
==================

Author:: Seth Chisamore (<schisamo@opscode.com>)
Author:: Bryan W. Berry (<bryan.berry@gmail.com>)

Copyright:: 2008-2012, Opscode, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
