#
# Author:: Bryan W. Berry (<bryan.berry@gmail.com>)
# Cookbook Name:: java
# Provider:: ark
#
# Copyright 2011, Bryan w. Berry
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

def whyrun_supported?
  true
end

def parse_app_dir_name url
  file_name = url.split('/')[-1]
  # funky logic to parse oracle's non-standard naming convention
  # for jdk1.6
  if file_name =~ /^(jre|jdk).*$/
    major_num = file_name.scan(/\d/)[0]
    update_num = file_name.scan(/\d+/)[1]
    # pad a single digit number with a zero
    if update_num.length < 2
      update_num = "0" + update_num
    end
    package_name = file_name.scan(/[a-z]+/)[0]
    app_dir_name = "#{package_name}1.#{major_num}.0_#{update_num}"
  else
    app_dir_name = file_name.split(/(.tgz|.tar.gz|.zip)/)[0]
    app_dir_name = app_dir_name.split("-bin")[0]
  end
  [app_dir_name, file_name]
end

def oracle_downloaded?(download_path, new_resource)
  if ::File.exists? download_path
    require 'digest'
    downloaded_sha =  Digest::SHA256.file(download_path).hexdigest
    downloaded_sha == new_resource.checksum
  else
    return false
  end
end

def download_direct_from_oracle(tarball_name, new_resource)
  download_path = "#{Chef::Config[:file_cache_path]}/#{tarball_name}"
  jdk_id = new_resource.url.scan(/\/([6789]u[0-9][0-9]?-b[0-9][0-9])\//)[0][0]
  cookie = "oraclelicensejdk-#{jdk_id}-oth-JPR=accept-securebackup-cookie;gpw_e24=http://edelivery.oracle.com"
  if node['java']['oracle']['accept_oracle_download_terms']
    # install the curl package
    p = package "curl" do
      action :nothing
    end
    # no converge_by block since the package provider will take care of this run_action
    p.run_action(:install)
    description = "download oracle tarball straight from the server"
    converge_by(description) do
       Chef::Log.debug "downloading oracle tarball straight from the source"
       cmd = Chef::ShellOut.new(
                                  %Q[ curl -L --cookie "#{cookie}" #{new_resource.url} -o #{download_path} ]
                               )
       cmd.run_command
       cmd.error!
    end
  else
    Chef::Application.fatal!("You must set the attribute node['java']['oracle']['accept_oracle_download_terms'] to true if you want to download directly from the oracle site!")
  end
end

action :install do
  app_dir_name, tarball_name = parse_app_dir_name(new_resource.url)
  app_root = new_resource.app_home.split('/')[0..-2].join('/')
  app_dir = app_root + '/' + app_dir_name

  unless new_resource.default
    Chef::Log.debug("processing alternate jdk")
    app_dir = app_dir  + "_alt"
    app_home = new_resource.app_home + "_alt"
  else
    app_home = new_resource.app_home
  end

  unless ::File.exists?(app_dir)
    Chef::Log.info "Adding #{new_resource.name} to #{app_dir}"
    require 'fileutils'

    unless ::File.exists?(app_root)
      description = "create dir #{app_root} and change owner to #{new_resource.owner}"
      converge_by(description) do
          FileUtils.mkdir app_root, :mode => new_resource.app_home_mode
          FileUtils.chown new_resource.owner, new_resource.owner, app_root
      end
    end

    if new_resource.url =~ /^http:\/\/download.oracle.com.*$/
      download_path = "#{Chef::Config[:file_cache_path]}/#{tarball_name}"
      if  oracle_downloaded?(download_path, new_resource)
        Chef::Log.debug("oracle tarball already downloaded, not downloading again")
      else
        download_direct_from_oracle tarball_name, new_resource
      end
    else
      Chef::Log.debug("downloading tarball from an unofficial repository")
      r = remote_file "#{Chef::Config[:file_cache_path]}/#{tarball_name}" do
        source new_resource.url
        checksum new_resource.checksum
        mode 0755
        action :nothing
      end
      #no converge by on run_action remote_file takes care of it.
      r.run_action(:create_if_missing)
    end

    require 'tmpdir'

    description = "create tmpdir, extract compressed data into tmpdir,
                    move extracted data to #{app_dir} and delete tmpdir"
    converge_by(description) do
       tmpdir = Dir.mktmpdir
       case tarball_name
       when /^.*\.bin/
         cmd = Chef::ShellOut.new(
                                  %Q[ cd "#{tmpdir}";
                                      cp "#{Chef::Config[:file_cache_path]}/#{tarball_name}" . ;
                                      bash ./#{tarball_name} -noregister
                                    ] ).run_command
         unless cmd.exitstatus == 0
           Chef::Application.fatal!("Failed to extract file #{tarball_name}!")
         end
       when /^.*\.zip/
         cmd = Chef::ShellOut.new(
                            %Q[ unzip "#{Chef::Config[:file_cache_path]}/#{tarball_name}" -d "#{tmpdir}" ]
                                  ).run_command
         unless cmd.exitstatus == 0
           Chef::Application.fatal!("Failed to extract file #{tarball_name}!")
         end
       when /^.*\.(tar.gz|tgz)/
         cmd = Chef::ShellOut.new(
                            %Q[ tar xvzf "#{Chef::Config[:file_cache_path]}/#{tarball_name}" -C "#{tmpdir}" ]
                                  ).run_command
         unless cmd.exitstatus == 0
           Chef::Application.fatal!("Failed to extract file #{tarball_name}!")
         end
       end

       cmd = Chef::ShellOut.new(
                          %Q[ mv "#{tmpdir}/#{app_dir_name}" "#{app_dir}" ]
                                ).run_command
       unless cmd.exitstatus == 0
           Chef::Application.fatal!(%Q[ Command \' mv "#{tmpdir}/#{app_dir_name}" "#{app_dir}" \' failed ])
         end
       FileUtils.rm_r tmpdir
     end
     new_resource.updated_by_last_action(true)
  end

  #set up .jinfo file for update-java-alternatives
  java_name =  app_home.split('/')[-1]
  jinfo_file = "#{app_root}/.#{java_name}.jinfo"
  if platform_family?("debian") && !::File.exists?(jinfo_file)
    description = "Add #{jinfo_file} for debian"
    converge_by(description) do
      Chef::Log.debug "Adding #{jinfo_file} for debian"
      template jinfo_file do
        source "oracle.jinfo.erb"
        variables(
          :priority => new_resource.alternatives_priority,
          :bin_cmds => new_resource.bin_cmds,
          :name => java_name,
          :app_dir => app_home
        ) 
        action :create
      end
    end
    new_resource.updated_by_last_action(true)
  end
  
  #link app_home to app_dir
  Chef::Log.debug "app_home is #{app_home} and app_dir is #{app_dir}"
  current_link = ::File.symlink?(app_home) ? ::File.readlink(app_home) : nil
  if current_link != app_dir
    description = "Symlink #{app_dir} to #{app_home}"
    converge_by(description) do
       Chef::Log.debug "Symlinking #{app_dir} to #{app_home}"
       FileUtils.rm_f app_home
       FileUtils.ln_sf app_dir, app_home
    end
  end

  #update-alternatives     
  if new_resource.bin_cmds
    new_resource.bin_cmds.each do |cmd|

      bin_path = "/usr/bin/#{cmd}"
      alt_path = "#{app_home}/bin/#{cmd}"
      priority = new_resource.alternatives_priority

      # install the alternative if needed
      alternative_exists = Chef::ShellOut.new("update-alternatives --display #{cmd} | grep #{alt_path}").run_command.exitstatus == 0
      unless alternative_exists
        description = "Add alternative for #{cmd}"
        converge_by(description) do
          Chef::Log.debug "Adding alternative for #{cmd}"
          install_cmd = Chef::ShellOut.new("update-alternatives --install #{bin_path} #{cmd} #{alt_path} #{priority}").run_command
          unless install_cmd.exitstatus == 0
            Chef::Application.fatal!(%Q[ set alternative failed ])
          end
        end
        new_resource.updated_by_last_action(true)
      end

      # set the alternative if default
      if new_resource.default
        alternative_is_set = Chef::ShellOut.new("update-alternatives --display #{cmd} | grep \"link currently points to #{alt_path}\"").run_command.exitstatus == 0
        unless alternative_is_set
          description = "Set alternative for #{cmd}"
          converge_by(description) do
            Chef::Log.debug "Setting alternative for #{cmd}"
            set_cmd = Chef::ShellOut.new("update-alternatives --set #{cmd} #{alt_path}").run_command
            unless set_cmd.exitstatus == 0
              Chef::Application.fatal!(%Q[ set alternative failed ])
            end
          end
          new_resource.updated_by_last_action(true)
        end
      end
      
    end
  end
end


action :remove do
  app_dir_name, tarball_name = parse_app_dir_name(new_resource.url)
  app_root = new_resource.app_home.split('/')[0..-2].join('/')
  app_dir = app_root + '/' + app_dir_name

  if ::File.exists?(app_dir)
    new_resource.bin_cmds.each do |cmd|
      cmd = execute "update_alternatives" do
        command "update-alternatives --remove #{cmd} #{app_dir} "
        returns [0,2]
        action :nothing
      end
      # the execute resource will take care of of the run_action(:run)
      cmd.run_action(:run)
    end
    description = "remove #{new_resource.name} at #{app_dir}"
    converge_by(description) do
       Chef::Log.info "Removing #{new_resource.name} at #{app_dir}"
       FileUtils.rm_rf app_dir
    end
    new_resource.updated_by_last_action(true)
  end
end
