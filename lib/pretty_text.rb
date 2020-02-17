# frozen_string_literal: true

require 'mini_racer'
require 'nokogiri'
require 'erb'

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
    ctx.eval("__PRETTY_TEXT = true")

    ctx_load(ctx, "#{Rails.root}/app/assets/javascripts/discourse-loader.js")
    ctx_load(ctx, "vendor/assets/javascripts/lodash.js")
    ctx_load_manifest(ctx, "pretty-text-bundle.js")
    ctx_load_manifest(ctx, "markdown-it-bundle.js")
    root_path = "#{Rails.root}/app/assets/javascripts/"

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

      buffer = +<<~JS
        __optInput = {};
        __optInput.siteSettings = #{SiteSetting.client_settings_json};
        #{"__optInput.disableEmojis = true" if opts[:disable_emojis]}
        __paths = #{paths_json};
        __optInput.getURL = __getURL;
        #{"__optInput.features = #{opts[:features].to_json};" if opts[:features]}
        __optInput.getCurrentUser = __getCurrentUser;
        __optInput.lookupAvatar = __lookupAvatar;
        __optInput.lookupPrimaryUserGroup = __lookupPrimaryUserGroup;
        __optInput.formatUsername = __formatUsername;
        __optInput.getTopicInfo = __getTopicInfo;
        __optInput.categoryHashtagLookup = __categoryLookup;
        __optInput.customEmoji = #{custom_emoji.to_json};
        __optInput.emojiUnicodeReplacer = __emojiUnicodeReplacer;
        __optInput.lookupUploadUrls = __lookupUploadUrls;
        __optInput.censoredRegexp = #{WordWatcher.word_matcher_regexp(:censor)&.source.to_json};
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
    return title unless SiteSetting.enable_emoji? && title

    set = SiteSetting.emoji_set.inspect
    custom = Emoji.custom.map { |e| [e.name, e.url] }.to_h.to_json

    protect do
      v8.eval(<<~JS)
        __paths = #{paths_json};
        __performEmojiUnescape(#{title.inspect}, {
          getURL: __getURL,
          emojiSet: #{set},
          customEmoji: #{custom},
          enableEmojiShortcuts: #{SiteSetting.enable_emoji_shortcuts},
          inlineEmoji: #{SiteSetting.enable_inline_emoji_translation}
        });
      JS
    end
  end

  def self.escape_emoji(title)
    return unless title

    replace_emoji_shortcuts = SiteSetting.enable_emoji && SiteSetting.enable_emoji_shortcuts

    protect do
      v8.eval(<<~JS)
        __performEmojiEscape(#{title.inspect}, {
          emojiShortcuts: #{replace_emoji_shortcuts},
          inlineEmoji: #{SiteSetting.enable_inline_emoji_translation}
        });
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

    if SiteSetting.enable_mentions
      add_mentions(doc, user_id: opts[:user_id])
    end

    doc.to_html
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
           uri.host.ends_with?(".#{site_uri.host}") ||
           whitelist.any? { |u| uri.host == u || uri.host.ends_with?(".#{u}") }
          # we are good no need for nofollow
          l.remove_attribute("rel")
        else
          l["rel"] = "nofollow noopener"
        end
      rescue URI::Error
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
        url = +"/t/topic/#{aside["data-topic"]}"
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
    DiscourseEvent.trigger(:reduce_excerpt, doc, options)
    strip_image_wrapping(doc)
    strip_oneboxed_media(doc)
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
      rescue URI::Error
        # leave it
      end
    end
  end

  def self.strip_image_wrapping(doc)
    doc.css(".lightbox-wrapper .meta").remove
  end

  def self.strip_oneboxed_media(doc)
    doc.css("audio").remove
    doc.css("video").remove
  end

  def self.convert_vimeo_iframes(doc)
    doc.css("iframe[src*='player.vimeo.com']").each do |iframe|
      if iframe["data-original-href"].present?
        vimeo_url = UrlHelper.escape_uri(iframe["data-original-href"])
      else
        vimeo_id = iframe['src'].split('/').last
        vimeo_url = "https://vimeo.com/#{vimeo_id}"
      end
      iframe.replace "<p><a href='#{vimeo_url}'>#{vimeo_url}</a></p>"
    end
  end

  def self.strip_secure_media(doc)
    doc.css("a[href]").each do |a|
      if Upload.secure_media_url?(a["href"])
        target = %w(video audio).include?(a&.parent&.parent&.name) ? a.parent.parent : a
        target.replace "<p class='secure-media-notice'>#{I18n.t("emails.secure_media_placeholder")}</p>"
      end
    end
  end

  def self.format_for_email(html, post = nil)
    doc = Nokogiri::HTML.fragment(html)
    DiscourseEvent.trigger(:reduce_cooked, doc, post)
    strip_secure_media(doc) if post&.with_secure_media?
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

  private

  USER_TYPE ||= 'user'
  GROUP_TYPE ||= 'group'

  def self.add_mentions(doc, user_id: nil)
    elements = doc.css("span.mention")
    names = elements.map { |element| element.text[1..-1] }

    mentions = lookup_mentions(names, user_id: user_id)

    elements.each do |element|
      name = element.text[1..-1]
      name.downcase!

      if type = mentions[name]
        element.name = 'a'

        element.children = PrettyText::Helpers.format_username(
          element.children.text
        )

        case type
        when USER_TYPE
          element['href'] = "#{Discourse::base_uri}/u/#{name}"
        when GROUP_TYPE
          element['class'] = 'mention-group'
          element['href'] = "#{Discourse::base_uri}/groups/#{name}"
        end
      end
    end
  end

  def self.lookup_mentions(names, user_id: nil)
    return {} if names.blank?

    sql = <<~SQL
    (
      SELECT
        :user_type AS type,
        username_lower AS name
      FROM users
      WHERE username_lower IN (:names) AND staged = false
    )
    UNION
    (
      SELECT
        :group_type AS type,
        lower(name) AS name
      FROM groups
      WHERE lower(name) IN (:names) AND (#{Group.mentionable_sql_clause})
    )
    SQL

    user = User.find_by(id: user_id)
    names.each(&:downcase!)

    results = DB.query(sql,
      names: names,
      user_type: USER_TYPE,
      group_type: GROUP_TYPE,
      levels: Group.alias_levels(user),
      user_id: user_id
    )

    mentions = {}
    results.each { |result| mentions[result.name] = result.type }
    mentions
  end

end
