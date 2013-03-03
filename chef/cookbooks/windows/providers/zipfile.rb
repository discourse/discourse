#
# Author:: Doug MacEachern (<dougm@vmware.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Provider:: unzip
#
# Copyright:: 2010, VMware, Inc.
# Copyright:: 2011, Opscode, Inc.
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

include Windows::Helper

require 'find'

action :unzip do
  ensure_rubyzip_gem_installed
  Chef::Log.debug("unzip #{@new_resource.source} => #{@new_resource.path} (overwrite=#{@new_resource.overwrite})")

  Zip::ZipFile.open(cached_file(@new_resource.source, @new_resource.checksum)) do |zip|
    zip.each do |entry|
      path = ::File.join(@new_resource.path, entry.name)
      FileUtils.mkdir_p(::File.dirname(path))
      if @new_resource.overwrite && ::File.exists?(path) && !::File.directory?(path)
        FileUtils.rm(path)
      end
      zip.extract(entry, path)
    end
  end
  @new_resource.updated_by_last_action(true)
end

action :zip do
  ensure_rubyzip_gem_installed
  # sanitize paths for windows.
  @new_resource.source.downcase.gsub!(::File::SEPARATOR, ::File::ALT_SEPARATOR)
  @new_resource.path.downcase.gsub!(::File::SEPARATOR, ::File::ALT_SEPARATOR)
  Chef::Log.debug("zip #{@new_resource.source} => #{@new_resource.path} (overwrite=#{@new_resource.overwrite})")

  if @new_resource.overwrite == false && ::File.exists?(@new_resource.path)
    Chef::Log.info("file #{@new_resource.path} already exists and overwrite is set to false, exiting")
  else
    # delete the archive if it already exists, because we are recreating it.
    if ::File.exists?(@new_resource.path)
      ::File.unlink(@new_resource.path)
    end
    # only supporting compression of a single directory (recursively).
    if ::File.directory?(@new_resource.source)
      z = Zip::ZipFile.new(@new_resource.path, true)
      unless @new_resource.source =~ /::File::ALT_SEPARATOR$/
        @new_resource.source << ::File::ALT_SEPARATOR
      end
      Find.find(@new_resource.source) do |f|
        f.downcase.gsub!(::File::SEPARATOR, ::File::ALT_SEPARATOR)
        # don't add root directory to the zipfile.
        next if f == @new_resource.source
        # strip the root directory from the filename before adding it to the zipfile.
        zip_fname = f.sub(@new_resource.source, '')
        Chef::Log.debug("adding #{zip_fname} to archive, sourcefile is: #{f}")
        z.add(zip_fname, f)
      end
      z.close
    else
      Chef::Log.info("Single directory must be specified for compression, and #{@new_resource.source} does not meet that criteria.")
    end
  end
end

private
def ensure_rubyzip_gem_installed
  begin
    require 'zip/zip'
  rescue LoadError
    Chef::Log.info("Missing gem 'rubyzip'...installing now.")
    chef_gem "rubyzip" do
      version node['windows']['rubyzipversion']
    end
    require 'zip/zip'
  end
end
