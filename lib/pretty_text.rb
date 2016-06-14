require 'mini_racer'
require 'nokogiri'
require 'erb'
require_dependency 'url_helper'
require_dependency 'excerpt_parser'
require_dependency 'post'
require_dependency 'discourse_tagging'
require_dependency 'pretty_text/helpers'

module PrettyText
  @mutex = Mutex.new
  @ctx_init = Mutex.new

  def self.app_root
    Rails.root
  end

  def self.find_file(root, filename)
    return filename if File.file?("#{root}#{filename}")

    es6_name = "#{filename}.js.es6"
    return es6_name if File.file?("#{root}#{es6_name}")

    js_name = "#{filename}.js"
    return js_name if File.file?("#{root}#{js_name}")

    erb_name = "#{filename}.js.es6.erb"
    return erb_name if File.file?("#{root}#{erb_name}")
  end

  def self.apply_es6_file(ctx, root_path, part_name)
    filename = find_file(root_path, part_name)
    if filename
      source = File.read("#{root_path}#{filename}")

      if filename =~ /\.erb$/
        source = ERB.new(source).result(binding)
      end

      template = Tilt::ES6ModuleTranspilerTemplate.new {}
      transpiled = template.module_transpile(source, "#{Rails.root}/app/assets/javascripts/", part_name)
      ctx.eval(transpiled)
    else
      # Look for vendored stuff
      vendor_root = "#{Rails.root}/vendor/assets/javascripts/"
      filename = find_file(vendor_root, part_name)
      if filename
        ctx.eval(File.read("#{vendor_root}#{filename}"))
      end
    end
  end

  def self.create_es6_context
    ctx = MiniRacer::Context.new(timeout: 15000)

    ctx.eval("window = {}; window.devicePixelRatio = 2;") # hack to make code think stuff is retina

    if Rails.env.development? || Rails.env.test?
      ctx.attach("console.log", proc{|l| p l })
    end

    ctx_load(ctx, "vendor/assets/javascripts/loader.js")
    ctx_load(ctx, "vendor/assets/javascripts/lodash.js")
    manifest = File.read("#{Rails.root}/app/assets/javascripts/pretty-text-bundle.js")
    root_path = "#{Rails.root}/app/assets/javascripts/"
    manifest.each_line do |l|
      if l =~ /\/\/= require (\.\/)?(.*)$/
        apply_es6_file(ctx, root_path, Regexp.last_match[2])
      elsif l =~ /\/\/= require_tree (\.\/)?(.*)$/
        path = Regexp.last_match[2]
        Dir["#{root_path}/#{path}/**"].each do |f|
          apply_es6_file(ctx, root_path, f.sub(root_path, '')[1..-1].sub(/\.js.es6$/, ''))
        end
      end
    end

    apply_es6_file(ctx, root_path, "discourse/lib/utilities")

    PrettyText::Helpers.instance_methods.each do |method|
      ctx.attach("__helpers.#{method}", PrettyText::Helpers.method(method))
    end
    ctx.load("#{Rails.root}/lib/pretty_text/shims.js")
    ctx.eval("__setUnicode(#{Emoji.unicode_replacements_json})")

    to_load = []
    DiscoursePluginRegistry.each_globbed_asset do |a|
      to_load << a if File.file?(a) && a =~ /discourse-markdown/
    end
    to_load.uniq.each do |f|
      if f =~ /^.+assets\/javascripts\//
        root = Regexp.last_match[0]
        apply_es6_file(ctx, root, f.sub(root, '').sub(/\.js\.es6$/, ''))
      end
    end

    ctx
  end

  def self.v8
    return @ctx if @ctx

    # ensure we only init one of these
    @ctx_init.synchronize do
      return @ctx if @ctx
      @ctx = create_es6_context
    end

    @ctx
  end

  def self.reset_context
    @ctx_init.synchronize do
      @ctx = nil
    end
  end

  def self.markdown(text, opts=nil)
    # we use the exact same markdown converter as the client
    # TODO: use the same extensions on both client and server (in particular the template for mentions)
    baked = nil
    text = text || ""

    protect do
      context = v8

      paths = {
        baseUri: Discourse::base_uri,
        CDN: Rails.configuration.action_controller.asset_host,
      }

      if SiteSetting.enable_s3_uploads?
        if SiteSetting.s3_cdn_url.present?
          paths[:S3CDN] = SiteSetting.s3_cdn_url
        end
        paths[:S3BaseUrl] = Discourse.store.absolute_base_url
      end

      context.eval("__optInput = {};")
      context.eval("__optInput.siteSettings = #{SiteSetting.client_settings_json};")
      context.eval("__paths = #{paths.to_json};")

      if opts[:topicId]
        context.eval("__optInput.topicId = #{opts[:topicId].to_i};")
      end

      context.eval("__optInput.getURL = __getURL;")
      context.eval("__optInput.lookupAvatar = __lookupAvatar;")
      context.eval("__optInput.getTopicInfo = __getTopicInfo;")
      context.eval("__optInput.categoryHashtagLookup = __categoryLookup;")
      context.eval("__optInput.mentionLookup = __mentionLookup;")

      custom_emoji = {}
      Emoji.custom.map {|e| custom_emoji[e.name] = e.url}
      context.eval("__optInput.customEmoji = #{custom_emoji.to_json};")

      opts = context.eval("__pt = new __PrettyText(__buildOptions(__optInput));")

      DiscourseEvent.trigger(:markdown_context, context)
      baked = context.eval("__pt.cook(#{text.inspect})")
    end

    if baked.blank? && !(opts || {})[:skip_blank_test]
      # we may have a js engine issue
      test = markdown("a", skip_blank_test: true)
      if test.blank?
        Rails.logger.warn("Markdown engine appears to have crashed, resetting context")
        reset_context
        opts ||= {}
        opts = opts.dup
        opts[:skip_blank_test] = true
        baked = markdown(text, opts)
      end
    end

    baked
  end

  # leaving this here, cause it invokes v8, don't want to implement twice
  def self.avatar_img(avatar_template, size)
    protect do
      v8.eval("__utils.avatarImg({size: #{size.inspect}, avatarTemplate: #{avatar_template.inspect}}, __getURL);")
    end
  end

  def self.unescape_emoji(title)
    return title unless SiteSetting.enable_emoji?

    set = SiteSetting.emoji_set.inspect
    protect do
      v8.eval("__performEmojiUnescape(#{title.inspect}, { getURL: __getURL, emojiSet: #{set} })")
    end
  end

  def self.cook(text, opts={})
    options = opts.dup

    # we have a minor inconsistency
    options[:topicId] = opts[:topic_id]

    working_text = text.dup
    sanitized = markdown(working_text, options)

    doc = Nokogiri::HTML.fragment(sanitized)

    if !options[:omit_nofollow] && SiteSetting.add_rel_nofollow_to_user_content
      add_rel_nofollow_to_user_content(doc)
    end

    if SiteSetting.enable_s3_uploads && SiteSetting.s3_cdn_url.present?
      add_s3_cdn(doc)
    end

    doc.to_html
  end

  def self.add_s3_cdn(doc)
    doc.css("img").each do |img|
      next unless img["src"]
      img["src"] = Discourse.store.cdn_url(img["src"])
    end
  end

  def self.add_rel_nofollow_to_user_content(doc)
    whitelist = []

    domains = SiteSetting.exclude_rel_nofollow_domains
    whitelist = domains.split('|') if domains.present?

    site_uri = nil
    doc.css("a").each do |l|
      href = l["href"].to_s
      begin
        uri = URI(href)
        site_uri ||= URI(Discourse.base_url)

        if !uri.host.present? ||
           uri.host == site_uri.host ||
           uri.host.ends_with?("." << site_uri.host) ||
           whitelist.any?{|u| uri.host == u || uri.host.ends_with?("." << u)}
          # we are good no need for nofollow
        else
          l["rel"] = "nofollow"
        end
      rescue URI::InvalidURIError, URI::InvalidComponentError
        # add a nofollow anyway
        l["rel"] = "nofollow"
      end
    end
  end

  class DetectedLink
    attr_accessor :is_quote, :url

    def initialize(url, is_quote=false)
      @url = url
      @is_quote = is_quote
    end
  end


  def self.extract_links(html)
    links = []
    doc = Nokogiri::HTML.fragment(html)
    # remove href inside quotes & elided part
    doc.css("aside.quote a, .elided a").each { |l| l["href"] = "" }

    # extract all links from the post
    doc.css("a").each { |l|
      unless l["href"].blank? || "#".freeze == l["href"][0]
        links << DetectedLink.new(l["href"])
      end
    }

    # extract links to quotes
    doc.css("aside.quote[data-topic]").each do |a|
      topic_id = a['data-topic']

      url = "/t/topic/#{topic_id}"
      if post_number = a['data-post']
        url << "/#{post_number}"
      end

      links << DetectedLink.new(url, true)
    end

    links
  end

  def self.excerpt(html, max_length, options={})
    # TODO: properly fix this HACK in ExcerptParser without introducing XSS
    doc = Nokogiri::HTML.fragment(html)
    strip_image_wrapping(doc)
    html = doc.to_html

    ExcerptParser.get_excerpt(html, max_length, options)
  end

  def self.strip_links(string)
    return string if string.blank?

    # If the user is not basic, strip links from their bio
    fragment = Nokogiri::HTML.fragment(string)
    fragment.css('a').each {|a| a.replace(a.inner_html) }
    fragment.to_html
  end

 # Given a Nokogiri doc, convert all links to absolute
 def self.make_all_links_absolute(doc)
   site_uri = nil
   doc.css("a").each do |link|
     href = link["href"].to_s
     begin
       uri = URI(href)
       site_uri ||= URI(Discourse.base_url)
       link["href"] = "#{site_uri}#{link['href']}" unless uri.host.present?
     rescue URI::InvalidURIError, URI::InvalidComponentError
       # leave it
     end
   end
 end

  def self.strip_image_wrapping(doc)
    doc.css(".lightbox-wrapper .meta").remove
  end

  def self.format_for_email(html, post = nil)
    doc = Nokogiri::HTML.fragment(html)
    DiscourseEvent.trigger(:reduce_cooked, doc, post)
    strip_image_wrapping(doc)
    make_all_links_absolute(doc)
    doc.to_html
  end

  protected

  class JavaScriptError < StandardError
    attr_accessor :message, :backtrace

    def initialize(message, backtrace)
      @message = message
      @backtrace = backtrace
    end

  end

  def self.protect
    rval = nil
    @mutex.synchronize do
      rval = yield
    end
    rval
  end

  def self.ctx_load(ctx, *files)
    files.each do |file|
      ctx.load(app_root + file)
    end
  end

end
