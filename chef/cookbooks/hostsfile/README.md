hostsfile LWRP
==============
[![Build Status](https://travis-ci.org/customink-webops/hostsfile.png?branch=master)](https://travis-ci.org/customink-webops/hostsfile)

`hostsfile` provides an LWRP for managing your `/etc/hosts` (or Windows equivalent) file using Chef.


Requirements
------------
- Chef 11 or higher
- **Ruby 1.9.3 or higher**

**Please stop opening Pull Requests to restore Ruby 1.8 support!** Any of the `1.x.y` series of this cookbook will work with Chef 10 and Ruby 1.8. You can use Opscode's [Omnibus installer](http://www.opscode.com/blog/2012/06/29/omnibus-chef-packaging/) to install Ruby 1.9+ and Seth Chisamore's [Vagrant Omnibus plugin](https://github.com/schisamo/vagrant-omnibus) to get Ruby 1.9+ on your Vagrant box.


Attributes
----------
<table>
  <tr>
    <th>Attribute</th>
    <th>Description</th>
    <th>Example</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>ip_address</td>
    <td>(name attribute) the IP address for the entry</td>
    <td><tt>1.2.3.4</tt></td>
    <td></td>
  </tr>
  <tr>
    <td>hostname</td>
    <td>(required) the hostname associated with the entry</td>
    <td><tt>example.com</tt></td>
    <td></td>
  </tr>
  <tr>
    <td>unique</td>
    <td>remove any existing entries that have the same <tt>hostname</tt></td>
    <td><tt>true</tt></td>
    <td><tt>false</tt></td>
  </tr>
  <tr>
    <td>aliases</td>
    <td>array of aliases for the entry</td>
    <td><tt>['www.example.com']</tt></td>
    <td><tt>[]</tt></td>
  </tr>
  <tr>
    <td>comment</td>
    <td>a comment to append to the end of the entry</td>
    <td><tt>'interal DNS server'</tt></td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td>priority</td>
    <td>the relative position of this entry</td>
    <td><tt>20</tt></td>
    <td>(varies, see **Priorities** section)</td>
  </tr>
</table>


Actions
-------
**Please note**: In `v0.1.2`, specifying a hostname or alias that existed in another automatically removed that hostname from the other entry before. In `v2.1.0`, the `unique` option was added to give the user case-by-case control of this behavior. For example, given an `/etc/hosts` file that contains:

    1.2.3.4          example.com www.example.com

when the Chef recipe below is converged:

```ruby
hostsfile_entry '2.3.4.5' do
  hostname  'www.example.com'
  unique    true
end
```

then the `/etc/hosts` file will look like this:

    1.2.3.4          example.com
    2.3.4.5          www.example.com

Not specifying the `unique` parameter will result in duplicate hostsfile entries.

#### `create`
Creates a new hosts file entry. If an entry already exists, it will be overwritten by this one.

```ruby
hostsfile_entry '1.2.3.4' do
  hostname  'example.com'
  action    :create
end
```

This will create an entry like this:

    1.2.3.4          example.com

#### `create_if_missing`
Create a new hosts file entry, only if one does not already exist for the given IP address. If one exists, this does nothing.

```ruby
hostsfile_entry '1.2.3.4' do
  hostname  'example.com'
  action    :create_if_missing
end
```

#### `append`
Append a hostname or alias to an existing record. If the given IP address doesn't not already exist in the hostsfile, this method behaves the same as create. Otherwise, it will append the additional hostname and aliases to the existing entry.

    1.2.3.4         example.com www.example.com # Created by Chef

```ruby
hostsfile_entry '1.2.3.4' do
  hostname  'www2.example.com'
  aliases   ['foo.com', 'foobar.com']
  comment   'Append by Recipe X'
  action    :append
end
```

would yield:

    1.2.3.4         example.com www.example.com www2.example.com foo.com foobar.com # Created by Chef, Appended by Recipe X


#### `update`
Updates the given hosts file entry. Does nothing if the entry does not exist.

```ruby
hostsfile_entry '1.2.3.4' do
  hostname  'example.com'
  comment   'Update by Chef'
  action    :update
end
```

This will create an entry like this:

    1.2.3.4           example # Updated by Chef

#### `remove`
Removes an entry from the hosts file. Does nothing if the entry does not
exist.

```ruby
hostsfile_entry '1.2.3.4' do
  action    :remove
end
```

This will remove the entry for `1.2.3.4`.


Usage
-----
If you're using [Berkshelf](http://berkshelf.com/), just add `hostsfile` to your `Berksfile`:

```ruby
cookbook 'hostsfile'
```

Otherwise, install the cookbook from the community site:

    knife cookbook site install hostsfile

Have any other cookbooks *depend* on hostsfile by editing editing the `metadata.rb` for your cookbook.

```ruby
# metadata.rb
depends 'hostsfile'
```


Priority
--------
Priority is a relatively new addition to the cookbook. It gives you the ability to (somewhat) specify the relative order of entries. By default, the priority is calculated for you as follows:

1. Local, loopback
2. IPV4
3. IPV6

However, you can override it using the `priority` option.


Contributing
------------
1. Fork the project
2. Create a feature branch corresponding to you change
3. Commit and test thoroughly
4. Create a Pull Request on github


License & Authors
-----------------
- Author:: Seth Vargo (sethvargo@gmail.com)

```text
Copyright 2012-2013, Seth Vargo
Copyright 2012, CustomInk, LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
