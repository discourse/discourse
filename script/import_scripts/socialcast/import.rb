# frozen_string_literal: true

require_relative './socialcast_message.rb'
require_relative './socialcast_user.rb'
require 'set'
require File.expand_path(File.dirname(__FILE__) + "/../base.rb")

class ImportScripts::Socialcast < ImportScripts::Base

  MESSAGES_DIR = "output/messages"
  USERS_DIR = "output/users"

  def initialize
    super
    @system_user = Discourse.system_user
  end

  def execute
    puts "", "Importing Socialcast Users..."
    import_users
    puts "", "Importing Socialcast Messages..."
    import_messages
    EmailToken.delete_all
    puts "", "Done"
  end

  def import_messages
    topics = 0
    imported = 0
    total = count_files(MESSAGES_DIR)
    Dir.foreach(MESSAGES_DIR) do |filename|
      next if filename == ('.') || filename == ('..')
      topics += 1
      message_json = File.read MESSAGES_DIR + '/' + filename
      message = SocialcastMessage.new(message_json)
      next unless message.title
      created_topic = import_topic message.topic
      if created_topic
        import_posts message.replies, created_topic.topic_id
      end
      imported += 1
      print_status topics, total
    end
    puts "", "Imported #{imported} topics. Skipped #{total - imported}."
  end

  def import_users
    users = 0
    total = count_files(USERS_DIR)
    Dir.foreach(USERS_DIR) do |filename|
      next if filename == ('.') || filename == ('..')
      user_json = File.read USERS_DIR + '/' + filename
      user = SocialcastUser.new(user_json).user
      create_user user, user[:id]
      users += 1
      print_status users, total
    end
  end

  def count_files(path)
    Dir.foreach(path).select { |f| f != '.' && f != '..' }.count
  end

  def import_topic(topic)
    post = nil
    if post_id = post_id_from_imported_post_id(topic[:id])
      post = Post.find(post_id) # already imported this topic
    else
      topic[:user_id] = user_id_from_imported_user_id(topic[:author_id]) || -1

      post = create_post(topic, topic[:id])

      unless post.is_a?(Post)
        puts "Error creating topic #{topic[:id]}. Skipping."
        puts post.inspect
      end
    end

    post
  end

  def import_posts(posts, topic_id)
    posts.each do |post|
      import_post post, topic_id
    end
  end

  def import_post(post, topic_id)
    return if post_id_from_imported_post_id(post[:id]) # already imported
    post[:topic_id] = topic_id
    post[:user_id] = user_id_from_imported_user_id(post[:author_id]) || -1
    new_post = create_post post, post[:id]
    unless new_post.is_a?(Post)
      puts "Error creating post #{post[:id]}. Skipping."
      puts new_post.inspect
    end
  end

end

if __FILE__ == $0
  ImportScripts::Socialcast.new.perform
end
