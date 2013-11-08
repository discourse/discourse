#
# Author:: Seth Vargo <sethvargo@gmail.com>
# Cookbook:: hostsfile
# Provider:: entry
#
# Copyright 2012-2013, Seth Vargo
# Copyright 2012, CustomInk, LCC
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

# Support whyrun
def whyrun_supported?
  true
end

# Creates a new hosts file entry. If an entry already exists, it will be
# overwritten by this one.
action :create do
  if hostsfile.contains?(new_resource)
    Chef::Log.debug "#{new_resource} already exists - overwriting."
  end

  converge_by("Create #{new_resource}") do
    hostsfile.add(
      ip_address: new_resource.ip_address,
      hostname:   new_resource.hostname,
      aliases:    new_resource.aliases,
      comment:    new_resource.comment,
      priority:   new_resource.priority,
      unique:     new_resource.unique,
    )
    hostsfile.save
  end
end

# Create a new hosts file entry, only if one does not already exist for
# the given IP address. If one exists, this does nothing.
action :create_if_missing do
  if hostsfile.contains?(new_resource)
    Chef::Log.info "#{new_resource} already exists - skipping create_if_missing."
  else
    converge_by("Create #{new_resource} if missing") do
      hostsfile.add(
        ip_address: new_resource.ip_address,
        hostname:   new_resource.hostname,
        aliases:    new_resource.aliases,
        comment:    new_resource.comment,
        priority:   new_resource.priority,
        unique:     new_resource.unique,
      )
      hostsfile.save
    end
  end
end

# Appends the given data to an existing entry. If an entry does not exist,
# one will be created
action :append do
  unless hostsfile.contains?(new_resource)
    Chef::Log.info "#{new_resource} does not exist - creating instead."
  end

  converge_by("Append #{new_resource}") do
    hostsfile.append(
      ip_address: new_resource.ip_address,
      hostname:   new_resource.hostname,
      aliases:    new_resource.aliases,
      comment:    new_resource.comment,
      priority:   new_resource.priority,
      unique:     new_resource.unique,
    )
    hostsfile.save
  end
end

# Updates the given hosts file entry. Does nothing if the entry does not
# exist.
action :update do
  if hostsfile.contains?(new_resource)
    converge_by("Update #{new_resource}") do
      hostsfile.update(
        ip_address: new_resource.ip_address,
        hostname:   new_resource.hostname,
        aliases:    new_resource.aliases,
        comment:    new_resource.comment,
        priority:   new_resource.priority,
        unique:     new_resource.unique,
      )
      hostsfile.save
    end
  else
    Chef::Log.info "#{new_resource} does not exist - skipping update."
  end
end

# Removes an entry from the hosts file. Does nothing if the entry does
# not exist.
action :remove do
  if hostsfile.contains?(new_resource)
    converge_by("Remove #{new_resource}") do
      hostsfile.remove(new_resource.ip_address)
      hostsfile.save
    end
  else
    Chef::Log.info "#{new_resource} does not exist - skipping remove."
  end
end

private
  # The hostsfile object
  #
  # @return [Manipulator]
  #   the manipulator for this hostsfile
  def hostsfile
    @hostsfile ||= Manipulator.new(node)
  end
