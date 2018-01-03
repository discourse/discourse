require 'nokogiri'
require 'optparse'
require File.expand_path(File.dirname(__FILE__) + "/base")

class ImportScripts::Disqus < ImportScripts::Base
  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  IMPORT_FILE = File.expand_path("~/import/site/export.xml")
  IMPORT_CATEGORY = "Front page"

  def initialize
    abort("File '#{IMPORT_FILE}' not found") if !File.exist?(IMPORT_FILE)

    @category = Category.where(name: IMPORT_CATEGORY).first
    abort("Category #{IMPORT_CATEGORY} not found") if @category.blank?

    @parser = DisqusSAX.new
    doc = Nokogiri::XML::SAX::Parser.new(@parser)
    doc.parse_file(IMPORT_FILE)
    @parser.normalize

    super
  end

  def execute
    import_users
    import_topics_and_posts
  end

  def import_users
    puts "", "importing users..."

    by_email = {}

    @parser.posts.each do |id, p|
      next if p[:is_spam] == 'true' || p[:is_deleted] == 'true'
      by_email[p[:author_email]] = { name: p[:author_name], username: p[:author_username] }
    end

    @parser.threads.each do |id, t|
      by_email[t[:author_email]] = { name: t[:author_name], username: t[:author_username] }
    end

    create_users(by_email.keys) do |email|
      user = by_email[email]
      {
        id: email,
        email: email,
        username: user[:username],
        name: user[:name],
        merge: true
      }
    end
  end

  def import_topics_and_posts
    puts "", "importing topics..."

    @parser.threads.each do |id, t|

      title = t[:title]
      title.gsub!(/&#8220;/, '"')
      title.gsub!(/&#8221;/, '"')
      title.gsub!(/&#8217;/, "'")
      title.gsub!(/&#8212;/, "--")
      title.gsub!(/&#8211;/, "-")

      puts "Creating #{title}... (#{t[:posts].size} posts)"

      topic_user = find_existing_user(t[:author_email], t[:author_username])
      begin
        post = TopicEmbed.import_remote(topic_user, t[:link], title: title)
        post.topic.update_column(:category_id, @category.id)
      rescue OpenURI::HTTPError
        post = nil
      end

      if post.present? && post.topic.posts_count <= 1
        (t[:posts] || []).each do |p|
          post_user = find_existing_user(p[:author_email] || '', p[:author_username])
          next unless post_user.present?

          attrs = {
            user_id: post_user.id,
            topic_id: post.topic_id,
            raw: p[:cooked],
            cooked: p[:cooked],
            created_at: Date.parse(p[:created_at])
          }

          if p[:parent_id]
            parent = @parser.posts[p[:parent_id]]

            if parent && parent[:discourse_number]
              attrs[:reply_to_post_number] = parent[:discourse_number]
            end
          end

          post = create_post(attrs, p[:id])
          p[:discourse_number] = post.post_number
        end
      end
    end
  end

  private

  def get_post_as_user(username)
    user = User.find_by_username_lower(username.downcase)
    abort("No user found named: '#{username}'") if user.nil?
    user
  end
end

class DisqusSAX < Nokogiri::XML::SAX::Document
  attr_accessor :posts, :threads, :users

  def initialize
    @inside = {}
    @posts = {}
    @threads = {}
    @users = {}
  end

  def start_element(name, attrs = [])

    hashed = Hash[attrs]
    case name
    when 'post'
      @post = {}
      @post[:id] = hashed['dsq:id'] if @post
    when 'thread'
      id = hashed['dsq:id']
      if @post
        thread = @threads[id]
        thread[:posts] << @post
      else
        @thread = { id: id, posts: [] }
      end
    when 'parent'
      if @post
        id = hashed['dsq:id']
        @post[:parent_id] = id
      end
    end

    @inside[name] = true
  end

  def end_element(name)
    case name
    when 'post'
      @posts[@post[:id]] = @post
      @post = nil
    when 'thread'
      if @post.nil?
        @threads[@thread[:id]] = @thread
        @thread = nil
      end
    end

    @inside[name] = false
  end

  def characters(str)
    record(@post, :author_email, str, 'author', 'email')
    record(@post, :author_name, str, 'author', 'name')
    record(@post, :author_username, str, 'author', 'username')
    record(@post, :author_anonymous, str, 'author', 'isAnonymous')
    record(@post, :created_at, str, 'createdAt')
    record(@post, :is_deleted, str, 'isDeleted')
    record(@post, :is_spam, str, 'isSpam')

    record(@thread, :link, str, 'link')
    record(@thread, :title, str, 'title')
    record(@thread, :created_at, str, 'createdAt')
    record(@thread, :author_email, str, 'author', 'email')
    record(@thread, :author_name, str, 'author', 'name')
    record(@thread, :author_username, str, 'author', 'username')
    record(@thread, :author_anonymous, str, 'author', 'isAnonymous')
  end

  def cdata_block(str)
    record(@post, :cooked, str, 'message')
  end

  def record(target, sym, str, *params)
    return if target.nil?

    if inside?(*params)
      target[sym] ||= ""
      target[sym] << str
    end
  end

  def inside?(*params)
    return !params.find { |p| !@inside[p] }
  end

  def normalize
    @threads.each do |id, t|
      if t[:posts].size == 0
        # Remove any threads that have no posts
        @threads.delete(id)
      else
        t[:posts].delete_if { |p| p[:is_spam] == 'true' || p[:is_deleted] == 'true' }
      end
    end

    # Merge any threads that have the same title
    existing_title = {}
    @threads.each do |id, t|
      existing = existing_title[t[:title]]
      if existing.nil?
        existing_title[t[:title]] = t
      else
        existing[:posts] << t[:posts]
        existing[:posts].flatten!
        @threads.delete(t[:id])
      end
    end
  end
end

ImportScripts::Disqus.new.perform
