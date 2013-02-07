#
# Cookbook Name:: apt
# Provider:: repository
#
# Copyright 2010-2011, Opscode, Inc.
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

def whyrun_supported?
  true
end

# install apt key from keyserver
def install_key_from_keyserver(key, keyserver)
  execute "install-key #{key}" do
    command "apt-key adv --keyserver #{keyserver} --recv #{key}"
    action :run
    not_if "apt-key list | grep #{key}"
  end
end

# run command and extract gpg ids
def extract_gpg_ids_from_cmd(cmd)
  so = Mixlib::ShellOut.new(cmd)
  so.run_command
  so.stdout.split(/\n/).collect do |t|
    if z = t.match(/^pub\s+\d+\w\/([0-9A-F]{8})/)
      z[1]
    end
  end.compact
end

# install apt key from URI
def install_key_from_uri(uri)
  key_name = uri.split(/\//).last
  cached_keyfile = "#{Chef::Config[:file_cache_path]}/#{key_name}"
  if new_resource.key =~ /http/
    remote_file cached_keyfile do
      source new_resource.key
      mode 00644
      action :create
    end
  else
    cookbook_file cached_keyfile do
      source new_resource.key
      cookbook new_resource.cookbook
      mode 00644
      action :create
    end
  end

  execute "install-key #{key_name}" do
    command "apt-key add #{cached_keyfile}"
    action :run
    not_if do
      installed_ids = extract_gpg_ids_from_cmd("apt-key finger")
      key_ids = extract_gpg_ids_from_cmd("gpg --with-fingerprint #{cached_keyfile}")
      (installed_ids & key_ids).sort == key_ids.sort
    end
  end
end

# build repo file contents
def build_repo(uri, distribution, components, arch, add_deb_src)
  components = components.join(' ') if components.respond_to?(:join)
  repo_info = "#{uri} #{distribution} #{components}\n"
  repo_info = "[arch=#{arch}] #{repo_info}" if arch
  repo =  "deb     #{repo_info}"
  repo << "deb-src #{repo_info}" if add_deb_src
  repo
end

action :add do
  new_resource.updated_by_last_action(false)
  @repo_file = nil

  recipe_eval do
    # add key
    if new_resource.keyserver && new_resource.key
      install_key_from_keyserver(new_resource.key, new_resource.keyserver)
    elsif new_resource.key
      install_key_from_uri(new_resource.key)
    end

    file "/var/lib/apt/periodic/update-success-stamp" do
      action :nothing
    end

    execute "apt-get update" do
      ignore_failure true
      action :nothing
    end

    # build repo file
    repository = build_repo(new_resource.uri,
                            new_resource.distribution,
                            new_resource.components,
                            new_resource.arch,
                            new_resource.deb_src)

    @repo_file = file "/etc/apt/sources.list.d/#{new_resource.name}.list" do
      owner "root"
      group "root"
      mode 00644
      content repository
      action :create
      notifies :delete, "file[/var/lib/apt/periodic/update-success-stamp]", :immediately
      notifies :run, "execute[apt-get update]", :immediately if new_resource.cache_rebuild
    end
  end

  raise RuntimeError, "The repository file to create is nil, cannot continue." if @repo_file.nil?
  new_resource.updated_by_last_action(@repo_file.updated?)
end

action :remove do
  if ::File.exists?("/etc/apt/sources.list.d/#{new_resource.name}.list")
    Chef::Log.info "Removing #{new_resource.name} repository from /etc/apt/sources.list.d/"
    file "/etc/apt/sources.list.d/#{new_resource.name}.list" do
      action :delete
    end
  end
end
