Description
===========

Installs ImageMagick and optionally Rmagick (RubyGem).

Requirements
============

## Platform:

Tested on:

* Ubuntu (10.04)
* RHEL (6.1, 5.7)

Usage
=====

To install just ImageMagick,

  include_recipe "imagemagick"

In your own recipe/cookbook. To install the development libraries,

  include_recipe "imagemagick::devel"

To install the RubyGem rmagick,

  include_recipe "imagemagick::rmagick"

Which will install imagemagick, as well as the development libraries for imagemagick (so rmagick can be built).

License and Author
==================

Author:: Joshua Timberman (<joshua@opscode.com>)

Copyright:: 2009, Opscode, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
