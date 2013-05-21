Description
===========

Creates a configured handler path for distributing [Chef report and exception handlers](http://wiki.opscode.com/display/chef/Exception+and+Report+Handlers).  Also exposes an LWRP for enabling Chef handlers from within recipe code (as opposed to hard coding in the client.rb file).  This is useful for cookbook authors who may want to ship a product specific handler (see the `cloudkick` cookbook for an example) with their cookbook.

Attributes
==========

`node["chef_handler"]["handler_path"]` - location to drop off handlers directory, default is `/var/chef/handlers`.

Resource/Provider
=================

`chef_handler`
--------------

Requires, configures and enables handlers on the node for the current Chef run.  Also has the ability to pass arguments to the handlers initializer.  This allows initialization data to be pulled from a node's attribute data.

It is best to declare `chef_handler` resources early on in the compile phase so they are available to fire for any exceptions during the Chef run.  If you have a base role you would want any recipes that register Chef handlers to come first in the run_list.

### Actions

- :enable: Enables the Chef handler for the current Chef run on the current node
- :disable: Disables the Chef handler for the current Chef run on the current node

### Attribute Parameters

- class_name: name attribute. The name of the handler class (can be module name-spaced).
- source: full path to the handler file.  can also be a gem path if the handler ships as part of a Ruby gem.
- arguments: an array of arguments to pass the handler's class initializer
- supports: type of Chef Handler to register as, ie :report, :exception or both. default is `:report => true, :exception => true`

### Example

    # register the Chef::Handler::JsonFile handler
    # that ships with the Chef gem
    chef_handler "Chef::Handler::JsonFile" do
      source "chef/handler/json_file"
      arguments :path => '/var/chef/reports'
      action :enable
    end

    # do the same but during the compile phase
    chef_handler "Chef::Handler::JsonFile" do
      source "chef/handler/json_file"
      arguments :path => '/var/chef/reports'
      action :nothing
    end.run_action(:enable)

    # handle exceptions only
    chef_handler "Chef::Handler::JsonFile" do
      source "chef/handler/json_file"
      arguments :path => '/var/chef/reports'
      supports :exception => true
      action :enable
    end


    # enable the CloudkickHandler which was
    # dropped off in the default handler path.
    # passes the oauth key/secret to the handler's
    # intializer.
    chef_handler "CloudkickHandler" do
      source "#{node['chef_handler']['handler_path']}/cloudkick_handler.rb"
      arguments [node['cloudkick']['oauth_key'], node['cloudkick']['oauth_secret']]
      action :enable
    end


Usage
=====

default
-------

Put the recipe `chef_handler` at the start of the node's run list to make sure that custom handlers are dropped off early on in the Chef run and available for later recipes.

For information on how to write report and exception handlers for Chef, please see the Chef wiki pages:
http://wiki.opscode.com/display/chef/Exception+and+Report+Handlers

json_file
---------

Leverages the `chef_handler` LWRP to automatically register the `Chef::Handler::JsonFile` handler that ships as part of Chef. This handler serializes the run status data to a JSON file located at `/var/chef/reports`.

License and Author
==================

Author:: Seth Chisamore (<schisamo@opscode.com>)

Copyright:: 2011, Opscode, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
