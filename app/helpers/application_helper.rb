# coding: utf-8
# frozen_string_literal: true
require 'current_user'
require 'canonical_url'

module ApplicationHelper
  include CurrentUser
  include CanonicalURL::Helpers
  include ConfigurableUrls
  include GlobalPath

  def self.extra_body_classes
    @extra_body_classes ||= Set.new
  end

  def google_universal_analytics_json(ua_domain_name = nil)
    result = {}
    if ua_domain_name
      result[:cookieDomain] = ua_domain_name.gsub(/^http(s)?:\/\//, '')
    end
    if current_user.present?
      result[:userId] = current_user.id
    end
    if SiteSetting.ga_universal_auto_link_domains.present?
      result[:allowLinker] = true
    end
    result.to_json
  end

  def ga_universal_json
    google_universal_analytics_json(SiteSetting.ga_universal_domain_name)
  end

  def google_tag_manager_json
    google_universal_analytics_json
  end

  def shared_session_key
    if SiteSetting.long_polling_base_url != '/'.freeze && current_user
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
    path = asset_path("#{script}.js")

    if GlobalSetting.use_s3? && GlobalSetting.s3_cdn_url
      if GlobalSetting.cdn_url
        folder = ActionController::Base.config.relative_url_root || "/"
        path = path.gsub(File.join(GlobalSetting.cdn_url, folder, "/"), File.join(GlobalSetting.s3_cdn_url, "/"))
      else
        # we must remove the subfolder path here, assets are uploaded to s3
        # without it getting involved
        if ActionController::Base.config.relative_url_root
          path = path.sub(ActionController::Base.config.relative_url_root, "")
        end

        path = "#{GlobalSetting.s3_cdn_url}#{path}"
      end

      if is_brotli_req?
        path = path.gsub(/\.([^.]+)$/, '.br.\1')
      elsif is_gzip_req?
        path = path.gsub(/\.([^.]+)$/, '.gz.\1')
      end

    elsif GlobalSetting.cdn_url&.start_with?("https") && is_brotli_req?
      path = path.gsub("#{GlobalSetting.cdn_url}/assets/", "#{GlobalSetting.cdn_url}/brotli_asset/")
    end

    if Rails.env == "development"
      if !path.include?("?")
        # cache breaker for mobile iOS
        path = path + "?#{Time.now.to_f}"
      end
    end

    path
  end

  def preload_script(script)
    path = script_asset_path(script)
    preload_script_url(path)
  end

  def preload_script_url(url)
    <<~HTML.html_safe
      <link rel="preload" href="#{url}" as="script">
      <script src="#{url}"></script>
    HTML
  end

  def discourse_csrf_tags
    # anon can not have a CSRF token cause these are all pages
    # that may be cached, causing a mismatch between session CSRF
    # and CSRF on page and horrible impossible to debug login issues
    if current_user
      csrf_meta_tags
    end
  end

  def html_classes
    list = []
    list << (mobile_view? ? 'mobile-view' : 'desktop-view')
    list << (mobile_device? ? 'mobile-device' : 'not-mobile-device')
    list << 'ios-device' if ios_device?
    list << 'rtl' if rtl?
    list << text_size_class
    list << 'anon' unless current_user
    list.join(' ')
  end

  def body_classes
    result = ApplicationHelper.extra_body_classes.to_a

    if @category && @category.url.present?
      result << "category-#{@category.url.sub(/^\/c\//, '').gsub(/\//, '-')}"
    end

    if current_user.present? &&
        current_user.primary_group_id &&
        primary_group_name = Group.where(id: current_user.primary_group_id).pluck_first(:name)
      result << "primary-group-#{primary_group_name.downcase}"
    end

    result.join(' ')
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
      javascript.gsub!(/\342\200\250/u, '&#x2028;')
      javascript.gsub!(/(<\/)/u, '\u003C/')
      javascript
    else
      ''
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
    ["ar", "ur", "fa_IR", "he"].include? I18n.locale.to_s
  end

  def html_lang
    SiteSetting.default_locale.sub("_", "-")
  end

  # Creates open graph and twitter card meta data
  def crawlable_meta_data(opts = nil)
    opts ||= {}
    opts[:url] ||= "#{Discourse.base_url_no_prefix}#{request.fullpath}"

    if opts[:image].blank?
      twitter_summary_large_image_url = SiteSetting.site_twitter_summary_large_image_url

      if twitter_summary_large_image_url.present?
        opts[:twitter_summary_large_image] = twitter_summary_large_image_url
      end

      opts[:image] = SiteSetting.site_opengraph_image_url
    end

    # Use the correct scheme for opengraph/twitter image
    opts[:image] = get_absolute_image_url(opts[:image]) if opts[:image].present?
    opts[:twitter_summary_large_image] =
      get_absolute_image_url(opts[:twitter_summary_large_image]) if opts[:twitter_summary_large_image].present?

    # Add opengraph & twitter tags
    result = []
    result << tag(:meta, property: 'og:site_name', content: SiteSetting.title)

    if opts[:twitter_summary_large_image].present?
      result << tag(:meta, name: 'twitter:card', content: "summary_large_image")
      result << tag(:meta, name: "twitter:image", content: opts[:twitter_summary_large_image])
    elsif opts[:image].present?
      result << tag(:meta, name: 'twitter:card', content: "summary")
      result << tag(:meta, name: "twitter:image", content: opts[:image])
    else
      result << tag(:meta, name: 'twitter:card', content: "summary")
    end
    result << tag(:meta, property: "og:image", content: opts[:image]) if opts[:image].present?

    [:url, :title, :description].each do |property|
      if opts[property].present?
        content = (property == :url ? opts[property] : gsub_emoji_to_unicode(opts[property]))
        result << tag(:meta, { property: "og:#{property}", content: content }, nil, true)
        result << tag(:meta, { name: "twitter:#{property}", content: content }, nil, true)
      end
    end

    if opts[:read_time] && opts[:read_time] > 0 && opts[:like_count] && opts[:like_count] > 0
      result << tag(:meta, name: 'twitter:label1', value: I18n.t("reading_time"))
      result << tag(:meta, name: 'twitter:data1', value: "#{opts[:read_time]} mins 🕑")
      result << tag(:meta, name: 'twitter:label2', value: I18n.t("likes"))
      result << tag(:meta, name: 'twitter:data2', value: "#{opts[:like_count]} ❤")
    end

    if opts[:published_time]
      result << tag(:meta, property: 'article:published_time', content: opts[:published_time])
    end

    if opts[:ignore_canonical]
      result << tag(:meta, property: 'og:ignore_canonical', content: true)
    end

    result.join("\n")
  end

  def render_sitelinks_search_tag
    json = {
      '@context' => 'http://schema.org',
      '@type' => 'WebSite',
      url: Discourse.base_url,
      potentialAction: {
        '@type' => 'SearchAction',
        target: "#{Discourse.base_url}/search?q={search_term_string}",
        'query-input' => 'required name=search_term_string',
      }
    }
    content_tag(:script, MultiJson.dump(json).html_safe, type: 'application/ld+json'.freeze)
  end

  def gsub_emoji_to_unicode(str)
    Emoji.gsub_emoji_to_unicode(str)
  end

  def application_logo_url
    @application_logo_url ||= begin
      if mobile_view? && SiteSetting.site_mobile_logo_url.present?
        SiteSetting.site_mobile_logo_url
      else
        SiteSetting.site_logo_url
      end
    end
  end

  def login_path
    "#{Discourse::base_uri}/login"
  end

  def mobile_view?
    MobileDetection.resolve_mobile_view!(request.user_agent, params, session)
  end

  def crawler_layout?
    controller&.use_crawler_layout?
  end

  def include_crawler_content?
    crawler_layout? || !mobile_view?
  end

  def mobile_device?
    MobileDetection.mobile_device?(request.user_agent)
  end

  def ios_device?
    MobileDetection.ios_device?(request.user_agent)
  end

  def customization_disabled?
    request.env[ApplicationController::NO_CUSTOM]
  end

  def include_ios_native_app_banner?
    current_user && current_user.trust_level >= 1 && SiteSetting.native_app_install_banner_ios
  end

  def ios_app_argument
    # argument only makes sense for DiscourseHub app
    SiteSetting.ios_app_id == "1173672076" ?
      ", app-argument=discourse://new?siteUrl=#{Discourse.base_url}" : ""
  end

  def allow_plugins?
    !request.env[ApplicationController::NO_PLUGINS]
  end

  def allow_third_party_plugins?
    allow_plugins? && !request.env[ApplicationController::ONLY_OFFICIAL]
  end

  def normalized_safe_mode
    safe_mode = []

    safe_mode << ApplicationController::NO_CUSTOM if customization_disabled?
    safe_mode << ApplicationController::NO_PLUGINS if !allow_plugins?
    safe_mode << ApplicationController::ONLY_OFFICIAL if !allow_third_party_plugins?

    safe_mode.join(",")
  end

  def loading_admin?
    controller.class.name.split("::").first == "Admin"
  end

  def category_badge(category, opts = nil)
    CategoryBadge.html_for(category, opts).html_safe
  end

  def self.all_connectors
    @all_connectors = Dir.glob("plugins/*/app/views/connectors/**/*.html.erb")
  end

  def server_plugin_outlet(name)

    # Don't evaluate plugins in test
    return "" if Rails.env.test?

    matcher = Regexp.new("/connectors/#{name}/.*\.html\.erb$")
    erbs = ApplicationHelper.all_connectors.select { |c| c =~ matcher }
    return "" if erbs.blank?

    result = +""
    erbs.each { |erb| result << render(inline: File.read(erb)) }
    result.html_safe
  end

  def topic_featured_link_domain(link)
    begin
      uri = UrlHelper.encode_and_parse(link)
      uri = URI.parse("http://#{uri}") if uri.scheme.nil?
      host = uri.host.downcase
      host.start_with?('www.') ? host[4..-1] : host
    rescue
      ''
    end
  end

  def theme_ids
    if customization_disabled?
      [nil]
    else
      request.env[:resolved_theme_ids]
    end
  end

  def scheme_id
    return if theme_ids.blank?
    Theme
      .where(id: theme_ids.first)
      .pluck(:color_scheme_id)
      .first
  end

  def current_homepage
    current_user&.user_option&.homepage || SiteSetting.anonymous_homepage
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
    Theme.lookup_field(theme_ids, mobile_view? ? :mobile : :desktop, name)
  end

  def theme_translations_lookup
    Theme.lookup_field(theme_ids, :translations, I18n.locale)
  end

  def theme_js_lookup
    Theme.lookup_field(theme_ids, :extra_js, nil)
  end

  def discourse_stylesheet_link_tag(name, opts = {})
    if opts.key?(:theme_ids)
      ids = opts[:theme_ids] unless customization_disabled?
    else
      ids = theme_ids
    end

    Stylesheet::Manager.stylesheet_link_tag(name, 'all', ids)
  end

  def preloaded_json
    return '{}' if @preloaded.blank?
    @preloaded.transform_values { |value| escape_unicode(value) }.to_json
  end

  def client_side_setup_data
    service_worker_url = Rails.env.development? ? 'service-worker.js' : Rails.application.assets_manifest.assets['service-worker.js']

    setup_data = {
      cdn: Rails.configuration.action_controller.asset_host,
      base_url: Discourse.base_url,
      base_uri: Discourse::base_uri,
      environment: Rails.env,
      letter_avatar_version: LetterAvatar.version,
      markdown_it_url: script_asset_path('markdown-it-bundle'),
      service_worker_url: service_worker_url,
      default_locale: SiteSetting.default_locale,
      asset_version: Discourse.assets_digest,
      disable_custom_css: loading_admin?,
      highlight_js_path: HighlightJs.path,
      svg_sprite_path: SvgSprite.path(theme_ids),
      enable_js_error_reporting: GlobalSetting.enable_js_error_reporting,
    }

    if Rails.env.development?
      setup_data[:svg_icon_list] = SvgSprite.all_icons(theme_ids)

      if ENV['DEBUG_PRELOADED_APP_DATA']
        setup_data[:debug_preloaded_app_data] = true
      end
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
    elsif link.start_with?("/uploads/")
      absolute_url = "#{Discourse.base_url}#{link}"
    elsif link.start_with?("/images/")
      absolute_url = "#{Discourse.base_url}#{link}"
    elsif GlobalSetting.relative_url_root && link.start_with?(GlobalSetting.relative_url_root)
      absolute_url = "#{Discourse.base_url_no_prefix}#{link}"
    end
    absolute_url
  end

  def can_sign_up?
    SiteSetting.allow_new_registrations &&
    !SiteSetting.invite_only &&
    !SiteSetting.enable_sso
  end
end
