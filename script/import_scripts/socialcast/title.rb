# frozen_string_literal: true

require_relative './socialcast_message.rb'
require_relative './socialcast_user.rb'
require 'set'
require File.expand_path(File.dirname(__FILE__) + "/../base.rb")

MESSAGES_DIR = "output/messages"

def titles
  topics = 0
  total = count_files(MESSAGES_DIR)
  Dir.foreach(MESSAGES_DIR) do |filename|
    next if filename == ('.') || filename == ('..')
    message_json = File.read MESSAGES_DIR + '/' + filename
    message = SocialcastMessage.new(message_json)
    next unless message.title
    #puts "#{filename}, #{message.replies.size}, #{message.topic[:raw].size}, #{message.message_type}, #{message.title}"
    puts "[#{message.title}](#{message.url})"
    topics += 1
  end
  puts "", "Imported #{topics} topics. Skipped #{total - topics}."
end

def count_files(path)
  Dir.foreach(path).select { |f| f != '.' && f != '..' }.count
end

titles
