# frozen_string_literal: true

require "mini_racer"
require "nokogiri"
require "erb"

module PrettyText
  DANGEROUS_BIDI_CHARACTERS = [
    "\u202A",
    "\u202B",
    "\u202C",
    "\u202D",
    "\u202E",
    "\u2066",
    "\u2067",
    "\u2068",
    "\u2069",
  ].freeze
  DANGEROUS_BIDI_REGEXP = Regexp.new(DANGEROUS_BIDI_CHARACTERS.join("|")).freeze

  BLOCKED_HOTLINKED_SRC_ATTR = "data-blocked-hotlinked-src"
  BLOCKED_HOTLINKED_SRCSET_ATTR = "data-blocked-hotlinked-srcset"

  @mutex = Mutex.new
  @ctx_init = Mutex.new

  def self.app_root
    Rails.root
  end

  def self.apply_es6_file(ctx:, path:, module_name:)
    source = File.read(path)
    transpiler = DiscourseJsProcessor::Transpiler.new
    transpiled = transpiler.perform(source, nil, module_name)
    ctx.eval(transpiled, filename: module_name)
  end

  def self.ctx_load_directory(ctx:, base_path:, module_prefix:)
    Dir["**/*.js", base: base_path].sort.each do |f|
      module_name = "#{module_prefix}#{f.delete_suffix(".js")}"
      apply_es6_file(ctx: ctx, path: File.join(base_path, f), module_name: module_name)
    end
  end

  def self.create_es6_context
    ctx = MiniRacer::Context.new(timeout: 25_000, ensure_gc_after_idle: 2000)

    ctx.eval("window = globalThis; window.devicePixelRatio = 2;") # hack to make code think stuff is retina

    ctx.attach("rails.logger.info", proc { |err| Rails.logger.info(err.to_s) })
    ctx.attach("rails.logger.warn", proc { |err| Rails.logger.warn(err.to_s) })
    ctx.attach("rails.logger.error", proc { |err| Rails.logger.error(err.to_s) })
    ctx.eval <<~JS
      console = {
        prefix: "[PrettyText] ",
        log: function(...args){ rails.logger.info(console.prefix + args.join(" ")); },
        warn: function(...args){ rails.logger.warn(console.prefix + args.join(" ")); },
        error: function(...args){ rails.logger.error(console.prefix + args.join(" ")); }
      }
    JS

    ctx.eval("__PRETTY_TEXT = true")

    PrettyText::Helpers.instance_methods.each do |method|
      ctx.attach("__helpers.#{method}", PrettyText::Helpers.method(method))
    end

    root_path = "#{Rails.root}/app/assets/javascripts"
    d_node_modules = "#{Rails.root}/app/assets/javascripts/discourse/node_modules"
    md_node_modules = "#{Rails.root}/app/assets/javascripts/discourse-markdown-it/node_modules"
    ctx.load("#{d_node_modules}/loader.js/dist/loader/loader.js")
    ctx.load("#{md_node_modules}/markdown-it/dist/markdown-it.js")
    ctx.load("#{root_path}/handlebars-shim.js")
    ctx.load("#{md_node_modules}/xss/dist/xss.js")
    ctx.load("#{Rails.root}/lib/pretty_text/vendor-shims.js")

    ctx_load_directory(
      ctx: ctx,
      base_path: "#{root_path}/pretty-text/addon",
      module_prefix: "pretty-text/",
    )
    ctx_load_directory(
      ctx: ctx,
      base_path: "#{root_path}/discourse-markdown-it/src",
      module_prefix: "discourse-markdown-it/",
    )

    %w[
      discourse-common/addon/deprecation-workflow
      discourse-common/addon/lib/get-url
      discourse-common/addon/lib/object
      discourse-common/addon/lib/deprecated
      discourse-common/addon/lib/escape
      discourse-common/addon/lib/avatar-utils
      discourse-common/addon/lib/case-converter
      discourse/app/lib/to-markdown
      discourse/app/static/markdown-it/features
    ].each do |f|
      apply_es6_file(
        ctx: ctx,
        path: "#{root_path}/#{f}.js",
        module_name: f.sub("/addon/", "/").sub("/app/", "/"),
      )
    end

    ctx.load("#{Rails.root}/lib/pretty_text/shims.js")
    ctx.eval("__setUnicode(#{Emoji.unicode_replacements_json})")

    Discourse.plugins.each do |plugin|
      Dir
        .glob("#{plugin.directory}/assets/javascripts/**/discourse-markdown/**/*.{js,js.es6}")
        .filter { |a| File.file?(a) }
        .each do |f|
          module_name =
            f.sub(%r{\A.+assets/javascripts/}, "discourse/plugins/#{plugin.name}/").sub(
              /\.js(\.es6)?\z/,
              "",
            )
          apply_es6_file(ctx: ctx, path: f, module_name: module_name)
        end
    end

    DiscoursePluginRegistry.vendored_core_pretty_text.each { |vpt| ctx.eval(File.read(vpt)) }

    DiscoursePluginRegistry.vendored_pretty_text.each { |vpt| ctx.eval(File.read(vpt)) }

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

  def self.reset_translations
    v8.eval("__resetTranslationTree()")
  end

  def self.reset_context
    @ctx_init.synchronize do
      @ctx&.dispose
      @ctx = nil
    end
  end

  # Acceptable options:
  #
  #  disable_emojis    - Disables the emoji markdown engine.
  #  features          - A hash where the key is the markdown feature name and the value is a boolean to enable/disable the markdown feature.
  #                      The hash is merged into the default features set in pretty-text.js which can be used to add new features or disable existing features.
  #  features_override - An array of markdown feature names to override the default markdown feature set. Currently used by plugins to customize what features should be enabled
  #                      when rendering markdown.
  #  markdown_it_rules - An array of markdown rule names which will be applied to the markdown-it engine. Currently used by plugins to customize what markdown-it rules should be
  #                      enabled when rendering markdown.
  #  topic_id          - Topic id for the post being cooked.
  #  post_id           - Post id for the post being cooked.
  #  user_id           - User id for the post being cooked.
  #  force_quote_link  - Always create the link to the quoted topic for [quote] bbcode. Normally this only happens
  #                      if the topic_id provided is different from the [quote topic:X].
  #  hashtag_context   - Defaults to "topic-composer" if not supplied. Controls the order of #hashtag lookup results
  #                      based on registered hashtag contexts from the `#register_hashtag_search_param` plugin API
  #                      method.
  def self.markdown(text, opts = {})
    # we use the exact same markdown converter as the client
    # TODO: use the same extensions on both client and server (in particular the template for mentions)
    baked = nil
    text = text || ""

    protect do
      context = v8

      custom_emoji = {}
      Emoji.custom.map { |e| custom_emoji[e.name] = e.url }

      # note, any additional options added to __optInput here must be
      # also be added to the buildOptions function in pretty-text.js,
      # otherwise they will be discarded
      buffer = +<<~JS
        __optInput = {};
        __optInput.siteSettings = #{SiteSetting.client_settings_json};
        #{"__optInput.disableEmojis = true" if opts[:disable_emojis]}
        __paths = #{paths_json};
        __optInput.getURL = __getURL;
        #{"__optInput.features = #{opts[:features].to_json};" if opts[:features]}
        #{"__optInput.featuresOverride = #{opts[:features_override].to_json};" if opts[:features_override]}
        #{"__optInput.markdownItRules = #{opts[:markdown_it_rules].to_json};" if opts[:markdown_it_rules]}
        __optInput.getCurrentUser = __getCurrentUser;
        __optInput.lookupAvatar = __lookupAvatar;
        __optInput.lookupPrimaryUserGroup = __lookupPrimaryUserGroup;
        __optInput.formatUsername = __formatUsername;
        __optInput.getTopicInfo = __getTopicInfo;
        __optInput.hashtagLookup = __hashtagLookup;
        __optInput.customEmoji = #{custom_emoji.to_json};
        __optInput.customEmojiTranslation = #{Plugin::CustomEmoji.translations.to_json};
        __optInput.emojiUnicodeReplacer = __emojiUnicodeReplacer;
        __optInput.emojiDenyList = #{Emoji.denied.to_json};
        __optInput.lookupUploadUrls = __lookupUploadUrls;
        __optInput.censoredRegexp = #{WordWatcher.serialized_regexps_for_action(:censor, engine: :js).to_json};
        __optInput.watchedWordsReplace = #{WordWatcher.regexps_for_action(:replace, engine: :js).to_json};
        __optInput.watchedWordsLink = #{WordWatcher.regexps_for_action(:link, engine: :js).to_json};
        __optInput.additionalOptions = #{Site.markdown_additional_options.to_json};
        __optInput.avatar_sizes = #{SiteSetting.avatar_sizes.to_json};
      JS

      buffer << "__optInput.topicId = #{opts[:topic_id].to_i};\n" if opts[:topic_id]
      buffer << "__optInput.postId = #{opts[:post_id].to_i};\n" if opts[:post_id]

      if opts[:force_quote_link]
        buffer << "__optInput.forceQuoteLink = #{opts[:force_quote_link]};\n"
      end

      buffer << "__optInput.userId = #{opts[:user_id].to_i};\n" if opts[:user_id]

      opts[:hashtag_context] = opts[:hashtag_context] || "topic-composer"
      hashtag_types_as_js =
        HashtagAutocompleteService
          .ordered_types_for_context(opts[:hashtag_context])
          .map { |t| "'#{t}'" }
          .join(",")
      buffer << "__optInput.hashtagTypesInPriorityOrder = [#{hashtag_types_as_js}];\n"
      buffer << "__optInput.hashtagIcons = #{HashtagAutocompleteService.data_source_icon_map.to_json};\n"

      buffer << "__pluginFeatures = __loadPluginFeatures();"
      buffer << "__pt = __DiscourseMarkdownIt.withCustomFeatures(__pluginFeatures).withOptions(__optInput);"

      # Be careful disabling sanitization. We allow for custom emails
      buffer << ("__pt.disableSanitizer();") if opts[:sanitize] == false

      opts = context.eval(buffer)

      DiscourseEvent.trigger(:markdown_context, context)
      baked = context.eval("__pt.cook(#{text.inspect})")
    end

    baked
  end

  def self.paths_json
    paths = { baseUri: Discourse.base_path, CDN: Rails.configuration.action_controller.asset_host }

    if SiteSetting.Upload.enable_s3_uploads
      paths[:S3CDN] = SiteSetting.Upload.s3_cdn_url if SiteSetting.Upload.s3_cdn_url.present?
      paths[:S3BaseUrl] = Discourse.store.absolute_base_url
    end

    paths.to_json
  end

  # leaving this here, cause it invokes v8, don't want to implement twice
  def self.avatar_img(avatar_template, size)
    protect { v8.eval(<<~JS) }
        __optInput = {};
        __optInput.avatar_sizes = #{SiteSetting.avatar_sizes.to_json};
        __paths = #{paths_json};
        require("discourse-common/lib/avatar-utils").avatarImg({size: #{size.inspect}, avatarTemplate: #{avatar_template.inspect}}, __getURL);
      JS
  end

  def self.unescape_emoji(title)
    return title unless SiteSetting.enable_emoji? && title

    set = SiteSetting.emoji_set.inspect
    custom = Emoji.custom.map { |e| [e.name, e.url] }.to_h.to_json

    protect { v8.eval(<<~JS) }
        __paths = #{paths_json};
        __performEmojiUnescape(#{title.inspect}, {
          getURL: __getURL,
          emojiSet: #{set},
          emojiCDNUrl: "#{SiteSetting.external_emoji_url.blank? ? "" : SiteSetting.external_emoji_url}",
          customEmoji: #{custom},
          enableEmojiShortcuts: #{SiteSetting.enable_emoji_shortcuts},
          inlineEmoji: #{SiteSetting.enable_inline_emoji_translation}
        });
      JS
  end

  def self.escape_emoji(title)
    return unless title

    replace_emoji_shortcuts = SiteSetting.enable_emoji && SiteSetting.enable_emoji_shortcuts

    protect { v8.eval(<<~JS) }
        __performEmojiEscape(#{title.inspect}, {
          emojiShortcuts: #{replace_emoji_shortcuts},
          inlineEmoji: #{SiteSetting.enable_inline_emoji_translation}
        });
      JS
  end

  def self.cook(text, opts = {})
    options = opts.dup
    working_text = text.dup

    sanitized = markdown(working_text, options)

    doc = Nokogiri::HTML5.fragment(sanitized)

    add_nofollow = !options[:omit_nofollow] && SiteSetting.add_rel_nofollow_to_user_content
    add_rel_attributes_to_user_content(doc, add_nofollow)
    strip_hidden_unicode_bidirectional_characters(doc)
    sanitize_hotlinked_media(doc)
    add_video_placeholder_image(doc)

    add_mentions(doc, user_id: opts[:user_id]) if SiteSetting.enable_mentions

    scrubber = Loofah::Scrubber.new { |node| node.remove if node.name == "script" }
    loofah_fragment = Loofah.html5_fragment(doc.to_html)
    loofah_fragment.scrub!(scrubber).to_html
  end

  def self.strip_hidden_unicode_bidirectional_characters(doc)
    return if !DANGEROUS_BIDI_REGEXP.match?(doc.content)

    doc
      .css("code,pre")
      .each do |code_tag|
        next if !DANGEROUS_BIDI_REGEXP.match?(code_tag.content)

        DANGEROUS_BIDI_CHARACTERS.each do |bidi|
          next if !code_tag.content.include?(bidi)

          formatted = "&lt;U+#{bidi.ord.to_s(16).upcase}&gt;"
          code_tag.inner_html =
            code_tag.inner_html.gsub(
              bidi,
              "<span class=\"bidi-warning\" title=\"#{I18n.t("post.hidden_bidi_character")}\">#{formatted}</span>",
            )
        end
      end
  end

  def self.sanitize_hotlinked_media(doc)
    return if !SiteSetting.block_hotlinked_media

    allowed_pattern = allowed_src_pattern

    doc
      .css("img[src], source[src], source[srcset], track[src], div[data-video-src]")
      .each do |el|
        if el["src"] && !el["src"].match?(allowed_pattern)
          el[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR] = el.delete("src")
        end
        if el["data-video-src"] && !el["data-video-src"].match?(allowed_pattern)
          el[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR] = el["data-video-src"]
        end

        if el["srcset"]
          srcs = el["srcset"].split(",").map { |e| e.split(" ", 2)[0].presence }
          if srcs.any? { |src| !src.match?(allowed_pattern) }
            el[PrettyText::BLOCKED_HOTLINKED_SRCSET_ATTR] = el.delete("srcset")
          end
        end
      end
  end

  def self.add_rel_attributes_to_user_content(doc, add_nofollow)
    allowlist = []

    domains = SiteSetting.exclude_rel_nofollow_domains
    allowlist = domains.split("|") if domains.present?

    site_uri = nil
    doc
      .css("a")
      .each do |l|
        href = l["href"].to_s
        l["rel"] = "noopener" if l["target"] == "_blank"

        begin
          uri = URI(UrlHelper.encode_component(href))
          site_uri ||= URI(Discourse.base_url)

          same_domain =
            !uri.host.present? || uri.host == site_uri.host ||
              uri.host.ends_with?(".#{site_uri.host}") ||
              allowlist.any? { |u| uri.host == u || uri.host.ends_with?(".#{u}") }

          l["rel"] = "noopener nofollow ugc" if add_nofollow && !same_domain
        rescue URI::Error
          # add a nofollow anyway
          l["rel"] = "noopener nofollow ugc"
        end
      end
  end

  class DetectedLink < Struct.new(:url, :is_quote)
  end

  def self.extract_links(html)
    links = []
    doc = Nokogiri::HTML5.fragment(html)

    # extract onebox links
    doc
      .css("aside.onebox[data-onebox-src]")
      .each { |onebox| links << DetectedLink.new(onebox["data-onebox-src"], false) }

    # remove href inside quotes & oneboxes & elided part
    doc.css("aside.quote a, aside.onebox a, .elided a").remove

    # remove hotlinked images
    doc.css("a.lightbox > img, a.onebox > img").each { |img| img.parent.remove }

    # extract all links
    doc
      .css("a")
      .each do |a|
        links << DetectedLink.new(a["href"], false) if a["href"].present? && a["href"][0] != "#"
      end

    # extract quotes
    doc
      .css("aside.quote[data-topic]")
      .each do |aside|
        if aside["data-topic"].present?
          url = +"/t/#{aside["data-topic"]}"
          url << "/#{aside["data-post"]}" if aside["data-post"].present?
          links << DetectedLink.new(url, true)
        end
      end

    # extract Youtube links
    doc
      .css("div[data-video-id]")
      .each do |div|
        if div["data-video-id"].present? && div["data-provider-name"].present?
          base_url =
            case div["data-provider-name"]
            when "youtube"
              "https://www.youtube.com/watch?v="
            when "vimeo"
              "https://vimeo.com/"
            when "tiktok"
              "https://m.tiktok.com/v/"
            end
          links << DetectedLink.new(base_url + div["data-video-id"], false)
        end
      end

    links
  end

  def self.add_video_placeholder_image(doc)
    doc
      .css(".video-placeholder-container")
      .each do |video|
        video_src = video["data-video-src"]
        next if video_src == "/404" || video_src.nil?
        video_sha1 = File.basename(video_src, File.extname(video_src))
        thumbnail = Upload.where("original_filename LIKE ?", "#{video_sha1}.%").last
        if thumbnail
          video["data-thumbnail-src"] = UrlHelper.absolute(
            GlobalPath.upload_cdn_path(thumbnail.url),
          )
        end
      end
  end

  def self.extract_mentions(cooked)
    mentions =
      cooked
        .css(".mention, .mention-group")
        .filter_map do |e|
          if (name = e.inner_text)
            User.normalize_username(name[1..-1]) if name[0] == "@"
          end
        end

    mentions =
      DiscoursePluginRegistry.apply_modifier(:pretty_text_extract_mentions, mentions, cooked)

    mentions.compact!
    mentions.uniq!
    mentions
  end

  def self.excerpt(html, max_length, options = {})
    # TODO: properly fix this HACK in ExcerptParser without introducing XSS
    doc = Nokogiri::HTML5.fragment(html)
    DiscourseEvent.trigger(:reduce_excerpt, doc, options)
    strip_image_wrapping(doc)
    strip_oneboxed_media(doc)
    convert_hashtag_links_to_plaintext(doc) if options[:plain_hashtags]

    html = doc.to_html
    ExcerptParser.get_excerpt(html, max_length, options)
  end

  def self.convert_hashtag_links_to_plaintext(doc)
    doc
      .css("a.hashtag-cooked")
      .each { |hashtag| hashtag.replace("##{hashtag.attributes["data-slug"]}") }
  end

  def self.strip_links(string)
    return string if string.blank?

    # If the user is not basic, strip links from their bio
    fragment = Nokogiri::HTML5.fragment(string)
    fragment.css("a").each { |a| a.replace(a.inner_html) }
    fragment.to_html
  end

  def self.make_all_links_absolute(doc)
    doc
      .css("a[href]")
      .each do |a|
        begin
          href = a["href"].to_s
          next if href.blank?
          next if href.start_with?("mailto:")
          next if href.start_with?(Discourse.base_url)
          next if URI(href).host.present?

          a["href"] = (
            if href.start_with?(Discourse.base_path)
              "#{Discourse.base_url_no_prefix}#{href}"
            else
              "#{Discourse.base_url}#{href}"
            end
          )
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
    doc.css(".video-onebox,video").remove
  end

  def self.convert_vimeo_iframes(doc)
    doc
      .css("iframe[src*='player.vimeo.com']")
      .each do |iframe|
        if iframe["data-original-href"].present?
          vimeo_url = UrlHelper.normalized_encode(iframe["data-original-href"])
        else
          vimeo_id = iframe["src"].split("/").last.sub("?h=", "/")
          vimeo_url = "https://vimeo.com/#{vimeo_id}"
        end
        iframe.replace Nokogiri::HTML5.fragment("<p><a href='#{vimeo_url}'>#{vimeo_url}</a></p>")
      end
  end

  def self.strip_secure_uploads(doc)
    # images inside a lightbox or other link
    doc
      .css("a[href]")
      .each do |a|
        next if !Upload.secure_uploads_url?(a["href"])

        non_image_media = %w[video audio].include?(a&.parent&.name)
        target = non_image_media ? a.parent : a
        if target.to_s.include?("stripped-secure-view-media") ||
             target.to_s.include?("stripped-secure-view-upload")
          next
        end

        next if a.css("img[src]").empty? && !non_image_media

        if a.classes.include?("lightbox")
          img = a.css("img[src]").first
          srcset = img&.attributes&.[]("srcset")&.value
          if srcset
            # if available, use the first image from the srcset here
            # so we get the optimized image instead of the possibly huge original
            url = srcset.split(",").first
          else
            url = img["src"]
          end
          a.add_next_sibling secure_uploads_placeholder(
                               doc,
                               url,
                               width: img["width"],
                               height: img["height"],
                             )
          a.remove
        else
          width = non_image_media ? nil : a.at_css("img").attr("width")
          height = non_image_media ? nil : a.at_css("img").attr("height")
          target.add_next_sibling secure_uploads_placeholder(
                                    doc,
                                    a["href"],
                                    width: width,
                                    height: height,
                                  )
          target.remove
        end
      end

    # images by themselves or inside a onebox
    doc
      .css("img[src]")
      .each do |img|
        url =
          if img.parent.classes.include?("aspect-image") && img.attributes["srcset"].present?
            # we are using the first image from the srcset here so we get the
            # optimized image instead of the original, because an optimized
            # image may be used for the onebox thumbnail
            srcset = img.attributes["srcset"].value
            srcset.split(",").first
          else
            img["src"]
          end

        width = img["width"]
        height = img["height"]
        onebox_type = nil

        if img.ancestors.css(".onebox-body").any?
          if img.classes.include?("onebox-avatar-inline")
            onebox_type = "avatar-inline"
          else
            onebox_type = "thumbnail"
          end
        end

        # we always want this to be tiny and without any special styles
        if img.classes.include?("site-icon")
          onebox_type = nil
          width = 16
          height = 16
        end

        if Upload.secure_uploads_url?(url)
          img.add_next_sibling secure_uploads_placeholder(
                                 doc,
                                 url,
                                 onebox_type: onebox_type,
                                 width: width,
                                 height: height,
                               )
          img.remove
        end
      end
  end

  def self.secure_uploads_placeholder(doc, url, onebox_type: false, width: nil, height: nil)
    data_width = width ? "data-width=#{width}" : ""
    data_height = height ? "data-height=#{height}" : ""
    data_onebox_type = onebox_type ? "data-onebox-type='#{onebox_type}'" : ""
    <<~HTML
    <div class="secure-upload-notice" data-stripped-secure-upload="#{url}" #{data_onebox_type} #{data_width} #{data_height}>
      #{I18n.t("emails.secure_uploads_placeholder")} <a class='stripped-secure-view-upload' href="#{url}">#{I18n.t("emails.view_redacted_media")}</a>.
    </div>
    HTML
  end

  def self.format_for_email(html, post = nil)
    doc = Nokogiri::HTML5.fragment(html)
    DiscourseEvent.trigger(:reduce_cooked, doc, post)
    strip_secure_uploads(doc) if post&.should_secure_uploads?
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
    @mutex.synchronize { rval = yield }
    rval
  end

  private

  USER_TYPE = "user"
  GROUP_TYPE = "group"
  GROUP_MENTIONABLE_TYPE = "group-mentionable"

  def self.add_mentions(doc, user_id: nil)
    elements = doc.css("span.mention")
    names = elements.map { |element| element.text[1..-1] }

    mentions = lookup_mentions(names, user_id: user_id)

    elements.each do |element|
      name = element.text[1..-1]
      name.downcase!

      if type = mentions[name]
        element.name = "a"

        element.children = PrettyText::Helpers.format_username(element.children.text)

        case type
        when USER_TYPE
          element["href"] = "#{Discourse.base_path}/u/#{UrlHelper.encode_component(name)}"
        when GROUP_MENTIONABLE_TYPE
          element["class"] = "mention-group notify"
          element["href"] = "#{Discourse.base_path}/groups/#{UrlHelper.encode_component(name)}"
        when GROUP_TYPE
          element["class"] = "mention-group"
          element["href"] = "#{Discourse.base_path}/groups/#{UrlHelper.encode_component(name)}"
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
    )
    UNION
    (
      SELECT
        :group_mentionable_type AS type,
        lower(name) AS name
      FROM groups
      WHERE lower(name) IN (:names) AND (#{Group.mentionable_sql_clause(include_public: false)})
    )
    ORDER BY type
    SQL

    user = User.find_by(id: user_id)
    names.each(&:downcase!)

    results =
      DB.query(
        sql,
        names: names,
        user_type: USER_TYPE,
        group_type: GROUP_TYPE,
        group_mentionable_type: GROUP_MENTIONABLE_TYPE,
        levels: Group.alias_levels(user),
        user_id: user_id,
      )

    mentions = {}
    results.each { |result| mentions[result.name] = result.type }
    mentions
  end

  def self.allowed_src_pattern
    allowed_src_prefixes = [
      Discourse.base_path,
      Discourse.base_url,
      GlobalSetting.s3_cdn_url,
      GlobalSetting.cdn_url,
      SiteSetting.external_emoji_url.presence,
      *SiteSetting.block_hotlinked_media_exceptions.split("|"),
    ]

    patterns =
      allowed_src_prefixes.compact.map do |url|
        pattern = Regexp.escape(url)

        # If 'https://example.com' is allowed, ensure 'https://example.com.blah.com' is not
        pattern += '(?:/|\z)' if !pattern.ends_with?("\/")

        pattern
      end

    /\A(data:|#{patterns.join("|")})/
  end
end
