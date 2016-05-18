require_relative './quandora_question.rb'
require File.expand_path(File.dirname(__FILE__) + "/../base.rb")

class ImportScripts::Quandora < ImportScripts::Base

  JSON_FILES_DIR = "output"

  def initialize
    super
    @system_user = Discourse.system_user
    @questions = []
    Dir.foreach(JSON_FILES_DIR) do |filename|
      next if filename == '.' or filename == '..'
      question = File.read JSON_FILES_DIR + '/' + filename
      @questions << question
    end
  end

  def execute
    puts "", "Importing from Quandora..."
    import_questions @questions
    EmailToken.delete_all
    puts "", "Done"
  end

  def import_questions questions
    topics = 0
    total = questions.size

    questions.each do |question|
      q = QuandoraQuestion.new question
      import_users q.users
      created_topic = import_topic q.topic
      if created_topic
        import_posts q.replies, created_topic.topic_id
      end
      topics += 1
      print_status topics, total
    end
    puts "", "Imported #{topics} topics."
  end

  def import_users users
    users.each do |user|
      create_user user, user[:id]
    end
  end

  def import_topic topic
    post = nil
    if post_id = post_id_from_imported_post_id(topic[:id])
      post = Post.find(post_id) # already imported this topic
    else
      topic[:user_id] = user_id_from_imported_user_id(topic[:author_id]) || -1
      topic[:category] = 'quandora-import'

      post = create_post(topic, topic[:id])

      unless post.is_a?(Post)
        puts "Error creating topic #{topic[:id]}. Skipping."
        puts post.inspect
      end
    end

    post
  end

  def import_posts posts, topic_id
    posts.each do |post|
      import_post post, topic_id
    end
  end

  def import_post post, topic_id
    if post_id_from_imported_post_id(post[:id])
      return # already imported
    end
    post[:topic_id] = topic_id
    post[:user_id] = user_id_from_imported_user_id(post[:author_id]) || -1
    new_post = create_post post, post[:id]
    unless new_post.is_a?(Post)
      puts "Error creating post #{post[:id]}. Skipping."
      puts new_post.inspect
    end
  end

  def file_full_path(relpath)
    File.join JSON_FILES_DIR, relpath.split("?").first
  end
end

if __FILE__==$0
  ImportScripts::Quandora.new.perform
end
