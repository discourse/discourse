# coding: utf-8
# frozen_string_literal: true
require "current_user"
require "canonical_url"

module ApplicationHelper
  include CurrentUser
  include CanonicalURL::Helpers
  include ConfigurableUrls
  include GlobalPath

  def self.extra_body_classes
    @extra_body_classes ||= Set.new
  end

  def discourse_config_environment(testing: false)
    # TODO: Can this come from Ember CLI somehow?
    config = {
      modulePrefix: "discourse",
      environment: Rails.env,
      rootURL: Discourse.base_path,
      locationType: "history",
      historySupportMiddleware: false,
      EmberENV: {
        FEATURES: {
        },
        EXTEND_PROTOTYPES: {
          Date: false,
          String: false,
        },
        _APPLICATION_TEMPLATE_WRAPPER: false,
        _DEFAULT_ASYNC_OBSERVERS: true,
        _JQUERY_INTEGRATION: true,
      },
      APP: {
        name: "discourse",
        version: "#{Discourse::VERSION::STRING} #{Discourse.git_version}",
        exportApplicationGlobal: true,
      },
    }

    if testing
      config[:environment] = "test"
      config[:locationType] = "none"
      config[:APP][:autoboot] = false
      config[:APP][:rootElement] = "#ember-testing"
    end

    config.to_json
  end

  def google_universal_analytics_json(ua_domain_name = nil)
    result = {}
    result[:cookieDomain] = ua_domain_name.gsub(%r{\Ahttp(s)?://}, "") if ua_domain_name
    result[:userId] = current_user.id if current_user.present?
    result[:allowLinker] = true if SiteSetting.ga_universal_auto_link_domains.present?
    result.to_json
  end

  def ga_universal_json
    google_universal_analytics_json(SiteSetting.ga_universal_domain_name)
  end

  def google_tag_manager_json
    google_universal_analytics_json
  end

  def csp_nonce_placeholder
    ContentSecurityPolicy.nonce_placeholder(response.headers)
  end

  def shared_session_key
    if SiteSetting.long_polling_base_url != "/" && current_user
      sk = "shared_session_key"
      return request.env[sk] if request.env[sk]

      request.env[sk] = key = (session[sk] ||= SecureRandom.hex)
      Discourse.redis.setex "#{sk}_#{key}", 7.days, current_user.id.to_s
      key
    end
  end

  def is_brotli_req?
    request.env["HTTP_ACCEPT_ENCODING"] =~ /br/
  end

  def is_gzip_req?
    request.env["HTTP_ACCEPT_ENCODING"] =~ /gzip/
  end

  def script_asset_path(script)
    path = ActionController::Base.helpers.asset_path("#{script}.js")

    if GlobalSetting.use_s3? && GlobalSetting.s3_cdn_url
      resolved_s3_asset_cdn_url =
        GlobalSetting.s3_asset_cdn_url.presence || GlobalSetting.s3_cdn_url
      if GlobalSetting.cdn_url
        folder = ActionController::Base.config.relative_url_root || "/"
        path =
          path.gsub(
            File.join(GlobalSetting.cdn_url, folder, "/"),
            File.join(resolved_s3_asset_cdn_url, "/"),
          )
      else
        # we must remove the subfolder path here, assets are uploaded to s3
        # without it getting involved
        if ActionController::Base.config.relative_url_root
          path = path.sub(ActionController::Base.config.relative_url_root, "")
        end

        path = "#{resolved_s3_asset_cdn_url}#{path}"
      end

      # assets needed for theme testing are not compressed because they take a fair
      # amount of time to compress (+30 seconds) during rebuilds/deploys when the
      # vast majority of sites will never need them, so it makes more sense to serve
      # them uncompressed instead of making everyone's rebuild/deploy take +30 more
      # seconds.
      if !script.start_with?("discourse/tests/")
        if is_brotli_req?
          path = path.gsub(/\.([^.]+)\z/, '.br.\1')
        elsif is_gzip_req?
          path = path.gsub(/\.([^.]+)\z/, '.gz.\1')
        end
      end
    end

    path
  end

  def preload_script(script)
    scripts = []

    if chunks = EmberCli.script_chunks[script]
      scripts.push(*chunks)
    else
      scripts.push(script)
    end

    scripts
      .map do |name|
        path = script_asset_path(name)
        preload_script_url(path, entrypoint: script)
      end
      .join("\n")
      .html_safe
  end

  def preload_script_url(url, entrypoint: nil)
    entrypoint_attribute = entrypoint ? "data-discourse-entrypoint=\"#{entrypoint}\"" : ""
    nonce_attribute = "nonce=\"#{csp_nonce_placeholder}\""

    add_resource_preload_list(url, "script")

    <<~HTML.html_safe
      <script defer src="#{url}" #{entrypoint_attribute} #{nonce_attribute}></script>
    HTML
  end

  def add_resource_preload_list(resource_url, type)
    links =
      controller.instance_variable_get(:@asset_preload_links) ||
        controller.instance_variable_set(:@asset_preload_links, [])
    links << %Q(<#{resource_url}>; rel="preload"; as="#{type}")
  end

  def discourse_csrf_tags
    # anon can not have a CSRF token cause these are all pages
    # that may be cached, causing a mismatch between session CSRF
    # and CSRF on page and horrible impossible to debug login issues
    csrf_meta_tags if current_user
  end

  def html_classes
    list = []
    list << (mobile_view? ? "mobile-view" : "desktop-view")
    list << (mobile_device? ? "mobile-device" : "not-mobile-device")
    list << "ios-device" if ios_device?
    list << "rtl" if rtl?
    list << text_size_class
    list << "anon" unless current_user
    list.join(" ")
  end

  def body_classes
    result = ApplicationHelper.extra_body_classes.to_a

    result << "category-#{@category.slug_path.join("-")}" if @category && @category.url.present?

    if current_user.present? && current_user.primary_group_id &&
         primary_group_name = Group.where(id: current_user.primary_group_id).pick(:name)
      result << "primary-group-#{primary_group_name.downcase}"
    end

    result.join(" ")
  end

  def text_size_class
    requested_cookie_size, cookie_seq = cookies[:text_size]&.split("|")
    server_seq = current_user&.user_option&.text_size_seq
    if cookie_seq && server_seq && cookie_seq.to_i >= server_seq &&
         UserOption.text_sizes.keys.include?(requested_cookie_size&.to_sym)
      cookie_size = requested_cookie_size
    end

    size = cookie_size || current_user&.user_option&.text_size || SiteSetting.default_text_size
    "text-size-#{size}"
  end

  def escape_unicode(javascript)
    if javascript
      javascript = javascript.scrub
      javascript.gsub!(/\342\200\250/u, "&#x2028;")
      javascript.gsub!(%r{(</)}u, '\u003C/')
      javascript
    else
      ""
    end
  end

  def format_topic_title(title)
    PrettyText.unescape_emoji strip_tags(title)
  end

  def with_format(format, &block)
    old_formats = formats
    self.formats = [format]
    block.call
    self.formats = old_formats
    nil
  end

  def age_words(secs)
    AgeWords.age_words(secs)
  end

  def short_date(dt)
    if dt.year == Time.now.year
      I18n.l(dt, format: :short_no_year)
    else
      I18n.l(dt, format: :date_only)
    end
  end

  def guardian
    @guardian ||= Guardian.new(current_user)
  end

  def admin?
    current_user.try(:admin?)
  end

  def moderator?
    current_user.try(:moderator?)
  end

  def staff?
    current_user.try(:staff?)
  end

  def rtl?
    Rtl::LOCALES.include? I18n.locale.to_s
  end

  def html_lang
    (request ? I18n.locale.to_s : SiteSetting.default_locale).sub("_", "-")
  end

  # Creates open graph and twitter card meta data
  def crawlable_meta_data(opts = nil)
    opts ||= {}
    opts[:url] ||= "#{Discourse.base_url_no_prefix}#{request.fullpath}"

    # if slug generation method is encoded, non encoded urls can sneak in
    # via bots
    url = opts[:url]
    if url.encoding.name != "UTF-8" || !url.valid_encoding?
      opts[:url] = url.dup.force_encoding("UTF-8").scrub!
    end

    if opts[:image].blank?
      twitter_summary_large_image_url = SiteSetting.site_twitter_summary_large_image_url

      if twitter_summary_large_image_url.present?
        opts[:twitter_summary_large_image] = twitter_summary_large_image_url
      end

      opts[:image] = SiteSetting.site_opengraph_image_url
    end

    # Use the correct scheme for opengraph/twitter image
    opts[:image] = get_absolute_image_url(opts[:image]) if opts[:image].present?
    opts[:twitter_summary_large_image] = get_absolute_image_url(
      opts[:twitter_summary_large_image],
    ) if opts[:twitter_summary_large_image].present?

    result = []
    result << tag(:meta, property: "og:site_name", content: opts[:site_name] || SiteSetting.title)
    result << tag(:meta, property: "og:type", content: "website")

    generate_twitter_card_metadata(result, opts)

    result << tag(:meta, property: "og:image", content: opts[:image]) if opts[:image].present?

    %i[url title description].each do |property|
      if opts[property].present?
        content = (property == :url ? opts[property] : gsub_emoji_to_unicode(opts[property]))
        result << tag(:meta, { property: "og:#{property}", content: content }, nil, true)
        result << tag(:meta, { name: "twitter:#{property}", content: content }, nil, true)
      end
    end
    Array
      .wrap(opts[:breadcrumbs])
      .each do |breadcrumb|
        result << tag(:meta, property: "og:article:section", content: breadcrumb[:name])
        result << tag(:meta, property: "og:article:section:color", content: breadcrumb[:color])
      end
    Array
      .wrap(opts[:tags])
      .each { |tag_name| result << tag(:meta, property: "og:article:tag", content: tag_name) }

    if opts[:read_time] && opts[:read_time] > 0 && opts[:like_count] && opts[:like_count] > 0
      result << tag(:meta, name: "twitter:label1", value: I18n.t("reading_time"))
      result << tag(:meta, name: "twitter:data1", value: "#{opts[:read_time]} mins 🕑")
      result << tag(:meta, name: "twitter:label2", value: I18n.t("likes"))
      result << tag(:meta, name: "twitter:data2", value: "#{opts[:like_count]} ❤")
    end

    if opts[:published_time]
      result << tag(:meta, property: "article:published_time", content: opts[:published_time])
    end

    result << tag(:meta, property: "og:ignore_canonical", content: true) if opts[:ignore_canonical]

    result.join("\n")
  end

  private def generate_twitter_card_metadata(result, opts)
    img_url =
      (
        if opts[:twitter_summary_large_image].present?
          opts[:twitter_summary_large_image]
        else
          opts[:image]
        end
      )

    # Twitter does not allow SVGs, see https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/markup
    if img_url.ends_with?(".svg")
      img_url = SiteSetting.site_logo_url.ends_with?(".svg") ? nil : SiteSetting.site_logo_url
    end

    if opts[:twitter_summary_large_image].present? && img_url.present?
      result << tag(:meta, name: "twitter:card", content: "summary_large_image")
      result << tag(:meta, name: "twitter:image", content: img_url)
    elsif opts[:image].present? && img_url.present?
      result << tag(:meta, name: "twitter:card", content: "summary")
      result << tag(:meta, name: "twitter:image", content: img_url)
    else
      result << tag(:meta, name: "twitter:card", content: "summary")
    end
  end

  def render_sitelinks_search_tag
    if current_page?("/") || current_page?(Discourse.base_path)
      json = {
        "@context" => "http://schema.org",
        "@type" => "WebSite",
        :url => Discourse.base_url,
        :name => SiteSetting.title,
        :potentialAction => {
          "@type" => "SearchAction",
          :target => "#{Discourse.base_url}/search?q={search_term_string}",
          "query-input" => "required name=search_term_string",
        },
      }
      content_tag(:script, MultiJson.dump(json).html_safe, type: "application/ld+json")
    end
  end

  def gsub_emoji_to_unicode(str)
    Emoji.gsub_emoji_to_unicode(str)
  end

  def application_logo_url
    @application_logo_url ||=
      begin
        if mobile_view?
          if dark_color_scheme? && SiteSetting.site_mobile_logo_dark_url.present?
            SiteSetting.site_mobile_logo_dark_url
          elsif SiteSetting.site_mobile_logo_url.present?
            SiteSetting.site_mobile_logo_url
          end
        else
          if dark_color_scheme? && SiteSetting.site_logo_dark_url.present?
            SiteSetting.site_logo_dark_url
          else
            SiteSetting.site_logo_url
          end
        end
      end
  end

  def application_logo_dark_url
    @application_logo_dark_url ||=
      begin
        if dark_scheme_id != -1
          if mobile_view? && SiteSetting.site_mobile_logo_dark_url != application_logo_url
            SiteSetting.site_mobile_logo_dark_url
          elsif !mobile_view? && SiteSetting.site_logo_dark_url != application_logo_url
            SiteSetting.site_logo_dark_url
          end
        end
      end
  end

  def waving_hand_url
    UrlHelper.cook_url(Emoji.url_for(":wave:t#{rand(2..6)}:"))
  end

  def login_path
    "#{Discourse.base_path}/login"
  end

  def mobile_view?
    MobileDetection.resolve_mobile_view!(request.user_agent, params, session)
  end

  def crawler_layout?
    controller&.use_crawler_layout?
  end

  def include_crawler_content?
    if current_user && !crawler_layout?
      params.key?(:print)
    else
      crawler_layout? || !mobile_view? || !modern_mobile_device?
    end
  end

  def modern_mobile_device?
    MobileDetection.modern_mobile_device?(request.user_agent)
  end

  def mobile_device?
    MobileDetection.mobile_device?(request.user_agent)
  end

  def ios_device?
    MobileDetection.ios_device?(request.user_agent)
  end

  def customization_disabled?
    request.env[ApplicationController::NO_THEMES]
  end

  def include_ios_native_app_banner?
    current_user && current_user.trust_level >= 1 && SiteSetting.native_app_install_banner_ios
  end

  def ios_app_argument
    # argument only makes sense for DiscourseHub app
    if SiteSetting.ios_app_id == "1173672076"
      ", app-argument=discourse://new?siteUrl=#{Discourse.base_url}"
    else
      ""
    end
  end

  def include_splash_screen?
    # A bit basic for now but will be expanded later
    SiteSetting.splash_screen
  end

  def allow_plugins?
    !request.env[ApplicationController::NO_PLUGINS]
  end

  def allow_third_party_plugins?
    allow_plugins? && !request.env[ApplicationController::NO_UNOFFICIAL_PLUGINS]
  end

  def normalized_safe_mode
    safe_mode = []

    safe_mode << ApplicationController::NO_THEMES if customization_disabled?
    safe_mode << ApplicationController::NO_PLUGINS if !allow_plugins?
    safe_mode << ApplicationController::NO_UNOFFICIAL_PLUGINS if !allow_third_party_plugins?

    safe_mode.join(",")
  end

  def loading_admin?
    return false unless defined?(controller)
    return false if controller.class.name.blank?

    controller.class.name.split("::").first == "Admin"
  end

  def category_badge(category, opts = nil)
    CategoryBadge.html_for(category, opts).html_safe
  end

  def self.all_connectors
    @all_connectors = Dir.glob("plugins/*/app/views/connectors/**/*.html.erb")
  end

  def server_plugin_outlet(name, locals: {})
    return "" if !GlobalSetting.load_plugins?

    matcher = Regexp.new("/connectors/#{name}/.*\.html\.erb$")
    erbs = ApplicationHelper.all_connectors.select { |c| c =~ matcher }
    return "" if erbs.blank?

    result = +""
    erbs.each { |erb| result << render(inline: File.read(erb), locals: locals) }
    result.html_safe
  end

  def topic_featured_link_domain(link)
    begin
      uri = UrlHelper.encode_and_parse(link)
      uri = URI.parse("http://#{uri}") if uri.scheme.nil?
      host = uri.host.downcase
      host.start_with?("www.") ? host[4..-1] : host
    rescue StandardError
      ""
    end
  end

  def theme_id
    if customization_disabled?
      nil
    else
      request.env[:resolved_theme_id]
    end
  end

  def async_stylesheets
    params["async_stylesheets"].to_s == "true"
  end

  def stylesheet_manager
    return @stylesheet_manager if defined?(@stylesheet_manager)
    @stylesheet_manager = Stylesheet::Manager.new(theme_id: theme_id)
  end

  def scheme_id
    return @scheme_id if defined?(@scheme_id)

    custom_user_scheme_id = cookies[:color_scheme_id] || current_user&.user_option&.color_scheme_id
    if custom_user_scheme_id && ColorScheme.find_by_id(custom_user_scheme_id)
      return custom_user_scheme_id
    end

    return if theme_id.blank?

    @scheme_id = Theme.where(id: theme_id).pick(:color_scheme_id)
  end

  def dark_scheme_id
    cookies[:dark_scheme_id] || current_user&.user_option&.dark_scheme_id ||
      SiteSetting.default_dark_mode_color_scheme_id
  end

  def current_homepage
    current_user&.user_option&.homepage || HomepageHelper.resolve(request, current_user)
  end

  def build_plugin_html(name)
    return "" unless allow_plugins?
    DiscoursePluginRegistry.build_html(name, controller) || ""
  end

  # If there is plugin HTML return that, otherwise yield to the template
  def replace_plugin_html(name)
    if (html = build_plugin_html(name)).present?
      html
    else
      yield
      nil
    end
  end

  def theme_lookup(name)
    Theme.lookup_field(
      theme_id,
      mobile_view? ? :mobile : :desktop,
      name,
      skip_transformation: request.env[:skip_theme_ids_transformation].present?,
      csp_nonce: csp_nonce_placeholder,
    )
  end

  def theme_translations_lookup
    Theme.lookup_field(
      theme_id,
      :translations,
      I18n.locale,
      skip_transformation: request.env[:skip_theme_ids_transformation].present?,
      csp_nonce: csp_nonce_placeholder,
    )
  end

  def theme_js_lookup
    Theme.lookup_field(
      theme_id,
      :extra_js,
      nil,
      skip_transformation: request.env[:skip_theme_ids_transformation].present?,
      csp_nonce: csp_nonce_placeholder,
    )
  end

  def discourse_stylesheet_preload_tag(name, opts = {})
    manager =
      if opts.key?(:theme_id)
        Stylesheet::Manager.new(theme_id: customization_disabled? ? nil : opts[:theme_id])
      else
        stylesheet_manager
      end

    manager.stylesheet_preload_tag(name, "all")
  end

  def discourse_stylesheet_link_tag(name, opts = {})
    manager =
      if opts.key?(:theme_id)
        Stylesheet::Manager.new(theme_id: customization_disabled? ? nil : opts[:theme_id])
      else
        stylesheet_manager
      end

    manager.stylesheet_link_tag(
      name,
      "all",
      self.method(:add_resource_preload_list),
      async_stylesheets,
    )
  end

  def discourse_preload_color_scheme_stylesheets
    result = +""
    result << stylesheet_manager.color_scheme_stylesheet_preload_tag(scheme_id, "all")

    if dark_scheme_id != -1
      result << stylesheet_manager.color_scheme_stylesheet_preload_tag(
        dark_scheme_id,
        "(prefers-color-scheme: dark)",
      )
    end

    result.html_safe
  end

  def discourse_color_scheme_stylesheets
    result = +""
    result << stylesheet_manager.color_scheme_stylesheet_link_tag(
      scheme_id,
      "all",
      self.method(:add_resource_preload_list),
      async_stylesheets,
    )

    if dark_scheme_id != -1
      result << stylesheet_manager.color_scheme_stylesheet_link_tag(
        dark_scheme_id,
        "(prefers-color-scheme: dark)",
        self.method(:add_resource_preload_list),
        async_stylesheets,
      )
    end

    result.html_safe
  end

  def discourse_theme_color_meta_tags
    result = +""
    if dark_scheme_id != -1
      result << <<~HTML
        <meta name="theme-color" media="(prefers-color-scheme: light)" content="##{ColorScheme.hex_for_name("header_background", scheme_id)}">
        <meta name="theme-color" media="(prefers-color-scheme: dark)" content="##{ColorScheme.hex_for_name("header_background", dark_scheme_id)}">
      HTML
    else
      result << <<~HTML
        <meta name="theme-color" media="all" content="##{ColorScheme.hex_for_name("header_background", scheme_id)}">
      HTML
    end
    result.html_safe
  end

  def discourse_color_scheme_meta_tag
    scheme =
      if dark_scheme_id == -1
        # no automatic client-side switching
        dark_color_scheme? ? "dark" : "light"
      else
        # auto-switched based on browser setting
        "light dark"
      end
    <<~HTML.html_safe
        <meta name="color-scheme" content="#{scheme}">
      HTML
  end

  def dark_color_scheme?
    return false if scheme_id.blank?
    ColorScheme.find_by_id(scheme_id)&.is_dark?
  end

  def preloaded_json
    return "{}" if @preloaded.blank?
    @preloaded.transform_values { |value| escape_unicode(value) }.to_json
  end

  def client_side_setup_data
    setup_data = {
      cdn: Rails.configuration.action_controller.asset_host,
      base_url: Discourse.base_url,
      base_uri: Discourse.base_path,
      environment: Rails.env,
      letter_avatar_version: LetterAvatar.version,
      service_worker_url: "service-worker.js",
      default_locale: SiteSetting.default_locale,
      asset_version: Discourse.assets_digest,
      disable_custom_css: loading_admin?,
      highlight_js_path: HighlightJs.path,
      svg_sprite_path: SvgSprite.path(theme_id),
      enable_js_error_reporting: GlobalSetting.enable_js_error_reporting,
      color_scheme_is_dark: dark_color_scheme?,
      user_color_scheme_id: scheme_id,
      user_dark_scheme_id: dark_scheme_id,
    }

    if Rails.env.development?
      setup_data[:svg_icon_list] = SvgSprite.all_icons(theme_id)

      setup_data[:debug_preloaded_app_data] = true if ENV["DEBUG_PRELOADED_APP_DATA"]
      setup_data[:mb_last_file_change_id] = MessageBus.last_id("/file-change")
    end

    if guardian.can_enable_safe_mode? && params["safe_mode"]
      setup_data[:safe_mode] = normalized_safe_mode
    end

    if SiteSetting.Upload.enable_s3_uploads
      setup_data[:s3_cdn] = SiteSetting.Upload.s3_cdn_url.presence
      setup_data[:s3_base_url] = SiteSetting.Upload.s3_base_url
    end

    setup_data
  end

  def get_absolute_image_url(link)
    absolute_url = link
    if link.start_with?("//")
      uri = URI(Discourse.base_url)
      absolute_url = "#{uri.scheme}:#{link}"
    elsif link.start_with?("/uploads/", "/images/", "/user_avatar/")
      absolute_url = "#{Discourse.base_url}#{link}"
    elsif GlobalSetting.relative_url_root && link.start_with?(GlobalSetting.relative_url_root)
      absolute_url = "#{Discourse.base_url_no_prefix}#{link}"
    end
    absolute_url
  end

  def escape_noscript(&block)
    raw capture(&block).gsub(%r{<(/\s*noscript)}i, '&lt;\1')
  end

  def manifest_url
    # If you want the `manifest_url` to be different for a specific action,
    # in the action set @manifest_url = X. Originally added for chat to add a
    # separate manifest
    @manifest_url || "#{Discourse.base_path}/manifest.webmanifest"
  end

  def can_sign_up?
    SiteSetting.allow_new_registrations && !SiteSetting.invite_only &&
      !SiteSetting.enable_discourse_connect
  end

  def rss_creator(user)
    user&.display_name
  end

  def anonymous_top_menu_items
    Discourse.anonymous_top_menu_items.map(&:to_s)
  end

  def authentication_data
    return @authentication_data if defined?(@authentication_data)

    @authentication_data =
      begin
        value = cookies[:authentication_data]
        cookies.delete(:authentication_data, path: Discourse.base_path("/")) if value
        current_user ? nil : value
      end
  end
end
