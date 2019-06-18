# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'socialcast_api'

def load_config(file)
  config = YAML::load_file(File.join(__dir__, file))
    @domain = config['domain']
    @username = config['username']
    @password = config['password']
end

def export
  @api = SocialcastApi.new @domain, @username, @password
  create_dir("output/users")
  create_dir("output/messages")
  export_users
  export_messages
end

def export_users(page = 1)
  users = @api.list_users(page: page)
  return if users.empty?
  users.each do |user|
    File.open("output/users/#{user['id']}.json", 'w') do |f|
      puts user['contact_info']['email']
      f.write user.to_json
      f.close
    end
  end
  export_users page + 1
end

def export_messages(page = 1)
  messages = @api.list_messages(page: page)
  return if messages.empty?
  messages.each do |message|
    File.open("output/messages/#{message['id']}.json", 'w') do |f|
      title = message['title']
      title = message['body'] if title.empty?
      title = title.split('\n')[0][0..50] unless title.empty?

      puts "#{message['id']}: #{title}"
      f.write message.to_json
      f.close
    end
  end
  export_messages page + 1
end

def create_dir(path)
  path = File.join(__dir__, path)
  unless File.directory?(path)
    FileUtils.mkdir_p(path)
  end
end

load_config ARGV.shift
export
