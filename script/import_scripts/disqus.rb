require 'nokogiri'
require 'optparse'
require File.expand_path(File.dirname(__FILE__) + "/base")

class ImportScripts::Disqus < ImportScripts::Base
  def initialize(options)
    verify_file(options[:file])
    @post_as_user = get_post_as_user(options[:post_as])
    @dry_run = options[:dry_run]
    @parser = DisqusSAX.new(options[:strip], options[:no_deleted])
    doc = Nokogiri::XML::SAX::Parser.new(@parser)
    doc.parse_file(options[:file])
    @parser.normalize
    super()
  end

  def execute
    @parser.threads.each do |id, t|
      puts "Creating #{t[:title]}... (#{t[:posts].size} posts)"

      if !@dry_run
        post = TopicEmbed.import_remote(@post_as_user, t[:link], title: t[:title])

        if post.present?
          t[:posts].each do |p|
            post_user = @post_as_user

            if p[:author_email]
              post_user = create_user({ id: nil, email: p[:author_email] }, nil)
            end

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

          TopicFeaturedUsers.new(post.topic).choose
        end
      end
    end
  end

  private

  def verify_file(file)
    abort("File '#{file}' not found") if !File.exist?(file)
  end

  def get_post_as_user(username)
    user = User.find_by_username_lower(username.downcase)
    abort("No user found named: '#{username}'") if user.nil?
    user
  end
end

class DisqusSAX < Nokogiri::XML::SAX::Document
  attr_accessor :posts, :threads

  def initialize(strip, no_deleted = false)
    @inside = {}
    @posts = {}
    @threads = {}
    @no_deleted = no_deleted
    @strip = strip
  end

  def start_element(name, attrs = [])
    case name
    when 'post'
      @post = {}
      @post[:id] = Hash[attrs]['dsq:id'] if @post
    when 'thread'
      id = Hash[attrs]['dsq:id']
      if @post
        # Skip this post if it's deleted and no_deleted is true
        return if @no_deleted && @post[:is_deleted].to_s == 'true'
        thread = @threads[id]
        thread[:posts] << @post
      else
        @thread = {id: id, posts: []}
      end
    when 'parent'
      if @post
        id = Hash[attrs]['dsq:id']
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
    record(@post, :author_anonymous, str, 'author', 'isAnonymous')
    record(@post, :created_at, str, 'createdAt')
    record(@post, :is_deleted, str, 'isDeleted')

    record(@thread, :link, str, 'link')
    record(@thread, :title, str, 'title')
    record(@thread, :created_at, str, 'createdAt')
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
    return !params.find{|p| !@inside[p]}
  end

  def normalize
    @threads.each do |id, t|
      if t[:posts].size == 0
        # Remove any threads that have no posts
        @threads.delete(id)
      else
        # Normalize titles
        t[:title] = [:title].gsub(@strip, '').strip if @strip.present?
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

options = {
  dry_run: false
}

OptionParser.new do |opts|
  opts.banner = 'Usage: RAILS_ENV=production ruby disqus.rb [OPTIONS]'

  opts.on('-f', '--file=FILE_PATH', 'The disqus XML file to import') do |value|
    options[:file] = value
  end

  opts.on('-d', '--dry_run', 'Just output what will be imported rather than doing it') do
    options[:dry_run] = true
  end

  opts.on('-p', '--post_as=USERNAME', 'The Discourse username to post as') do |value|
    options[:post_as] = value
  end

  opts.on('-D', '--no_deleted', 'Do not post deleted comments') do
    options[:no_deleted] = true
  end

  opts.on('-s', '--strip=TEXT', 'Text to strip from titles') do |value|
    options[:strip] = value
  end
end.parse!

ImportScripts::Disqus.new(options).perform
