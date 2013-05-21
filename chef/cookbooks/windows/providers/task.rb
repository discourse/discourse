#
# Author:: Paul Mooring (<paul@opscode.com>)
# Cookbook Name:: windows
# Provider:: task
#
# Copyright:: 2012, Opscode, Inc.
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

require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut

action :create do
  if @current_resource.exists
    Chef::Log.info "#{@new_resource} task already exists - nothing to do"
  else
    cmd =  "schtasks /Create /TN \"#{@new_resource.name}\" "
    cmd += "/SC #{@new_resource.frequency} /MO #{@new_resource.frequency_modifier} "
    cmd += "/TR \"#{@new_resource.command}\" "
    if @new_resource.user && @new_resource.password
      cmd += "/RU \"#{@new_resource.user}\" /RP \"#{@new_resource.password}\" "
    elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
      Chef::Log.fatal "#{@new_resource.name}: Can't specify user or password without both!"
    end
    cmd += "/RL HIGHEST " if @new_resource.run_level == :highest
    shell_out!(cmd, {:returns => [0]})
    @new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task created"
  end
end

action :run do
  if @current_resource.exists
    if @current_resource.status == :running
      Chef::Log.info "#{@new_resource} task is currently running, skipping run"
    else
      cmd = "schtasks /Run /TN \"#{@current_resource.name}\""
      shell_out!(cmd, {:returns => [0]})
      @new_resource.updated_by_last_action true
      Chef::Log.info "#{@new_resource} task ran"
    end
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :change do
  if @current_resource.exists
    cmd =  "schtasks /Change /TN \"#{@current_resource.name}\" "
    cmd += "/TR \"#{@new_resource.command}\" " if @new_resource.command
    if @new_resource.user && @new_resource.password
      cmd += "/RU \"#{@new_resource.user}\" /RP \"#{@new_resource.password}\" "
    elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
      Chef::Log.fatal "#{@new_resource.name}: Can't specify user or password without both!"
    end
    shell_out!(cmd, {:returns => [0]})
    @new_resource.updated_by_last_action true
    Chef::Log.info "Change #{@new_resource} task ran"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :delete do
  if @current_resource.exists
    cmd = "schtasks /Delete /TN \"#{@current_resource.name}\""
    shell_out!(cmd, {:returns => [0]})
    @new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task deleted"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsTask.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  task_hash = load_task_hash(@current_resource.name)
  if task_hash[:TaskName] == '\\' + @new_resource.name
    @current_resource.exists = true
    if task_hash[:Status] == "Running"
      @current_resource.status = :running
    end
    @current_resource.cwd(task_hash[:Folder])
    @current_resource.command(task_hash[:TaskToRun])
    @current_resource.user(task_hash[:RunAsUser])
  end if task_hash.respond_to? :[]
end

private

def load_task_hash(task_name)
  Chef::Log.debug "looking for existing tasks"
  output = `schtasks /Query /FO LIST /V /TN \"#{task_name}\" 2> NUL`
  if output.empty?
    task = false
  else
    task = Hash.new

    output.split("\n").map! do |line|
      line.split(":", 2).map! do |field|
        field.strip
      end
    end.each do |field|
      if field.kind_of? Array and field[0].respond_to? :to_sym
        task[field[0].gsub(/\s+/,"").to_sym] = field[1]
      end
    end
  end

  task
end
