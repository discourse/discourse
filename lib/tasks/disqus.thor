require 'nokogiri'

class DisqusSAX < Nokogiri::XML::SAX::Document
  attr_accessor :posts, :threads

  def initialize
    @inside = {}
    @posts = {}
    @threads = {}
  end

  def start_element(name, attrs = [])

    case name
    when 'post'
      @post = {}
      @post[:id] = Hash[attrs]['dsq:id'] if @post
    when 'thread'
      id = Hash[attrs]['dsq:id']
      if @post
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

    record(@thread, :link, str, 'link')
    record(@thread, :title, str, 'title')
    record(@thread, :created_at, str, 'createdAt')
  end

  def cdata_block(str)
    record(@post, :cooked, str, 'message')
  end

  def record(target, sym, str, *params)
    return if target.nil?
    target[sym] = str if inside?(*params)
  end

  def inside?(*params)
    return !params.find{|p| !@inside[p]}
  end

  def normalize

    # Remove any threads that have no posts
    @threads.each do |id, t|
      if t[:posts].size == 0
        @threads.delete(id)
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

class Disqus < Thor
  desc "import", "Imports posts from a Disqus XML export"
  method_option :file, aliases: '-f', required: true, desc: "The disqus XML file to import"
  method_option :post_as, aliases: '-p', required: true, desc: "The Discourse username to post as"
  method_option :category, aliases: '-c', desc: "The category to post in"
  def import
    require './config/environment'

    email_blacklist = SiteSetting.email_domains_blacklist

    user = User.where(username_lower: options[:post_as].downcase).first
    if user.nil?
      puts "No user found named: '#{options[:post_as]}'"
      exit 1
    end

    unless File.exist?(options[:file])
      puts "File '#{options[:file]}' not found"
      exit 1
    end

    parser = DisqusSAX.new
    doc = Nokogiri::XML::SAX::Parser.new(parser)
    doc.parse_file(options[:file])
    parser.normalize

    RateLimiter.disable

    SiteSetting.email_domains_blacklist = ""

    category_id = nil
    if options[:category]
      category_id = Category.where(name: options[:category]).first.try(:id)
    end

    parser.threads.each do |id, t|
      puts "Creating #{t[:title]}... (#{t[:posts].size} posts)"

      creator = PostCreator.new(user, title: t[:title], raw: "\[[Permalink](#{t[:link]})\]", created_at: Date.parse(t[:created_at]), category: category_id)
      post = creator.create

      if post.present?
        t[:posts].each do |p|
          post_user = user
          if p[:author_email]
            email = Email.downcase(p[:author_email])
            post_user = User.where(email: email).first
            if post_user.blank?
              post_user = User.create!(email: email, username: UserNameSuggester.suggest(email))
            end
          end

          attrs = {
            topic_id: post.topic_id,
            raw: p[:cooked],
            cooked: p[:cooked],
            created_at: Date.parse(p[:created_at])
          }

          if p[:parent_id]
            parent = parser.posts[p[:parent_id]]
            if parent && parent[:discourse_number]
              attrs[:reply_to_post_number] = parent[:discourse_number]
            end
          end

          post = PostCreator.new(post_user, attrs).create
          p[:discourse_number] = post.post_number
        end
        TopicFeaturedUsers.new(post.topic).choose
      end


    end

  ensure
    RateLimiter.enable
    SiteSetting.email_domains_blacklist = email_blacklist
  end
end


