require 'mini_racer'
require 'nokogiri'
require 'erb'
require_dependency 'url_helper'
require_dependency 'excerpt_parser'
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

  def self.ctx_load_manifest(ctx, name)
    manifest = File.read("#{Rails.root}/app/assets/javascripts/#{name}")
    root_path = "#{Rails.root}/app/assets/javascripts/"

    manifest.each_line do |l|
      l = l.chomp
      if l =~ /\/\/= require (\.\/)?(.*)$/
        apply_es6_file(ctx, root_path, Regexp.last_match[2])
      elsif l =~ /\/\/= require_tree (\.\/)?(.*)$/
        path = Regexp.last_match[2]
        Dir["#{root_path}/#{path}/**"].sort.each do |f|
          apply_es6_file(ctx, root_path, f.sub(root_path, '')[1..-1].sub(/\.js.es6$/, ''))
        end
      end
    end
  end

  def self.create_es6_context
    ctx = MiniRacer::Context.new(timeout: 15000)

    ctx.eval("window = {}; window.devicePixelRatio = 2;") # hack to make code think stuff is retina

    if Rails.env.development? || Rails.env.test?
      ctx.attach("console.log", proc { |l| p l })
      ctx.eval('window.console = console;')
    end

    ctx_load(ctx, "#{Rails.root}/app/assets/javascripts/discourse-loader.js")
    ctx_load(ctx, "vendor/assets/javascripts/lodash.js")
    ctx_load_manifest(ctx, "pretty-text-bundle.js")
    ctx_load_manifest(ctx, "markdown-it-bundle.js")
    root_path = "#{Rails.root}/app/assets/javascripts/"

    apply_es6_file(ctx, root_path, "discourse/helpers/parse-html")
    apply_es6_file(ctx, root_path, "discourse/lib/to-markdown")
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

    DiscoursePluginRegistry.vendored_core_pretty_text.each do |vpt|
      ctx.eval(File.read(vpt))
    end

    DiscoursePluginRegistry.vendored_pretty_text.each do |vpt|
      ctx.eval(File.read(vpt))
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
      @ctx&.dispose
      @ctx = nil
    end
  end

  def self.markdown(text, opts = {})
    # we use the exact same markdown converter as the client
    # TODO: use the same extensions on both client and server (in particular the template for mentions)
    baked = nil
    text = text || ""

    protect do
      context = v8

      custom_emoji = {}
      Emoji.custom.map { |e| custom_emoji[e.name] = e.url }

      buffer = <<~JS
        __optInput = {};
        __optInput.siteSettings = #{SiteSetting.client_settings_json};
        __paths = #{paths_json};
        __optInput.getURL = __getURL;
        __optInput.getCurrentUser = __getCurrentUser;
        __optInput.lookupAvatar = __lookupAvatar;
        __optInput.lookupPrimaryUserGroup = __lookupPrimaryUserGroup;
        __optInput.formatUsername = __formatUsername;
        __optInput.getTopicInfo = __getTopicInfo;
        __optInput.categoryHashtagLookup = __categoryLookup;
        __optInput.mentionLookup = __mentionLookup;
        __optInput.customEmoji = #{custom_emoji.to_json};
        __optInput.emojiUnicodeReplacer = __emojiUnicodeReplacer;
        __optInput.lookupInlineOnebox = __lookupInlineOnebox;
        __optInput.lookupImageUrls = __lookupImageUrls;
        __optInput.censoredWords = #{WordWatcher.words_for_action(:censor).join('|').to_json};
      JS

      if opts[:topicId]
        buffer << "__optInput.topicId = #{opts[:topicId].to_i};\n"
      end

      if opts[:user_id]
        buffer << "__optInput.userId = #{opts[:user_id].to_i};\n"
      end

      buffer << "__textOptions = __buildOptions(__optInput);\n"

      buffer << ("__pt = new __PrettyText(__textOptions);")

      # Be careful disabling sanitization. We allow for custom emails
      if opts[:sanitize] == false
        buffer << ('__pt.disableSanitizer();')
      end

      opts = context.eval(buffer)

      DiscourseEvent.trigger(:markdown_context, context)
      baked = context.eval("__pt.cook(#{text.inspect})")
    end

    # if baked.blank? && !(opts || {})[:skip_blank_test]
    #   # we may have a js engine issue
    #   test = markdown("a", skip_blank_test: true)
    #   if test.blank?
    #     Rails.logger.warn("Markdown engine appears to have crashed, resetting context")
    #     reset_context
    #     opts ||= {}
    #     opts = opts.dup
    #     opts[:skip_blank_test] = true
    #     baked = markdown(text, opts)
    #   end
    # end

    baked
  end

  def self.paths_json
    paths = {
      baseUri: Discourse::base_uri,
      CDN: Rails.configuration.action_controller.asset_host,
    }

    if SiteSetting.Upload.enable_s3_uploads
      if SiteSetting.Upload.s3_cdn_url.present?
        paths[:S3CDN] = SiteSetting.Upload.s3_cdn_url
      end
      paths[:S3BaseUrl] = Discourse.store.absolute_base_url
    end

    paths.to_json
  end

  # leaving this here, cause it invokes v8, don't want to implement twice
  def self.avatar_img(avatar_template, size)
    protect do
      v8.eval(<<~JS)
        __paths = #{paths_json};
        __utils.avatarImg({size: #{size.inspect}, avatarTemplate: #{avatar_template.inspect}}, __getURL);
      JS
    end
  end

  def self.unescape_emoji(title)
    return title unless SiteSetting.enable_emoji?

    set = SiteSetting.emoji_set.inspect
    protect do
      v8.eval(<<~JS)
        __paths = #{paths_json};
        __performEmojiUnescape(#{title.inspect}, { getURL: __getURL, emojiSet: #{set} });
      JS
    end
  end

  def self.cook(text, opts = {})
    options = opts.dup

    # we have a minor inconsistency
    options[:topicId] = opts[:topic_id]

    working_text = text.dup

    sanitized = markdown(working_text, options)

    doc = Nokogiri::HTML.fragment(sanitized)

    if !options[:omit_nofollow] && SiteSetting.add_rel_nofollow_to_user_content
      add_rel_nofollow_to_user_content(doc)
    end

    if SiteSetting.Upload.enable_s3_uploads && SiteSetting.Upload.s3_cdn_url.present?
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
           whitelist.any? { |u| uri.host == u || uri.host.ends_with?("." << u) }
          # we are good no need for nofollow
          l.remove_attribute("rel")
        else
          l["rel"] = "nofollow noopener"
        end
      rescue URI::InvalidURIError, URI::InvalidComponentError
        # add a nofollow anyway
        l["rel"] = "nofollow noopener"
      end
    end
  end

  class DetectedLink < Struct.new(:url, :is_quote); end

  def self.extract_links(html)
    links = []
    doc = Nokogiri::HTML.fragment(html)

    # remove href inside quotes & elided part
    doc.css("aside.quote a, .elided a").each { |a| a["href"] = "" }

    # extract all links
    doc.css("a").each do |a|
      if a["href"].present? && a["href"][0] != "#".freeze
        links << DetectedLink.new(a["href"], false)
      end
    end

    # extract quotes
    doc.css("aside.quote[data-topic]").each do |aside|
      if aside["data-topic"].present?
        url = "/t/topic/#{aside["data-topic"]}"
        url << "/#{aside["data-post"]}" if aside["data-post"].present?
        links << DetectedLink.new(url, true)
      end
    end

    # extract Youtube links
    doc.css("div[data-youtube-id]").each do |div|
      if div["data-youtube-id"].present?
        links << DetectedLink.new("https://www.youtube.com/watch?v=#{div['data-youtube-id']}", false)
      end
    end

    links
  end

  def self.excerpt(html, max_length, options = {})
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
    fragment.css('a').each { |a| a.replace(a.inner_html) }
    fragment.to_html
  end

  def self.make_all_links_absolute(doc)
    site_uri = nil
    doc.css("a").each do |link|
      href = link["href"].to_s
      begin
        uri = URI(href)
        site_uri ||= URI(Discourse.base_url)
        unless uri.host.present? || href.start_with?('mailto')
          link["href"] = "#{site_uri}#{link['href']}"
        end
      rescue URI::InvalidURIError, URI::InvalidComponentError
        # leave it
      end
    end
  end

  def self.strip_image_wrapping(doc)
    doc.css(".lightbox-wrapper .meta").remove
  end

  def self.convert_vimeo_iframes(doc)
    doc.css("iframe[src*='player.vimeo.com']").each do |iframe|
      vimeo_id = iframe['src'].split('/').last
      iframe.replace "<p><a href='https://vimeo.com/#{vimeo_id}'>https://vimeo.com/#{vimeo_id}</a></p>"
    end
  end

  def self.format_for_email(html, post = nil)
    doc = Nokogiri::HTML.fragment(html)
    DiscourseEvent.trigger(:reduce_cooked, doc, post)
    strip_image_wrapping(doc)
    convert_vimeo_iframes(doc)
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
