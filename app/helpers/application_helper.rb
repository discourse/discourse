# frozen_string_literal: true
require 'current_user'
require 'canonical_url'
require_dependency 'guardian'
require_dependency 'unread'
require_dependency 'age_words'
require_dependency 'configurable_urls'
require_dependency 'mobile_detection'
require_dependency 'category_badge'
require_dependency 'global_path'
require_dependency 'emoji'

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
    result.to_json.html_safe
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
      $redis.setex "#{sk}_#{key}", 7.days, current_user.id.to_s
      key
    end
  end

  def is_brotli_req?
    ENV["COMPRESS_BROTLI"] == "1" &&
    request.env["HTTP_ACCEPT_ENCODING"] =~ /br/
  end

  def preload_script(script)
    path = asset_path("#{script}.js")

    if GlobalSetting.use_s3? && GlobalSetting.s3_cdn_url
      if GlobalSetting.cdn_url
        path = path.gsub(GlobalSetting.cdn_url, GlobalSetting.s3_cdn_url)
      else
        path = "#{GlobalSetting.s3_cdn_url}#{path}"
      end

      if is_brotli_req?
        path = path.gsub(/\.([^.]+)$/, '.br.\1')
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

"<link rel='preload' href='#{path}' as='script'/>
<script src='#{path}'></script>".html_safe
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
    "#{mobile_view? ? 'mobile-view' : 'desktop-view'} #{mobile_device? ? 'mobile-device' : 'not-mobile-device'} #{rtl_class} #{current_user ? '' : 'anon'}"
  end

  def body_classes
    result = ApplicationHelper.extra_body_classes.to_a

    if @category && @category.url.present?
      result << "category-#{@category.url.sub(/^\/c\//, '').gsub(/\//, '-')}"
    end

    if current_user.present? && primary_group_name = current_user.primary_group&.name
      result << "primary-group-#{primary_group_name.downcase}"
    end

    result.join(' ')
  end

  def rtl_class
    rtl? ? 'rtl' : ''
  end

  def escape_unicode(javascript)
    if javascript
      javascript = javascript.scrub
      javascript.gsub!(/\342\200\250/u, '&#x2028;')
      javascript.gsub!(/(<\/)/u, '\u003C/')
      javascript.html_safe
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

  def mini_profiler_enabled?
    defined?(Rack::MiniProfiler) && admin?
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

  def user_locale
    locale = current_user.locale if current_user && SiteSetting.allow_user_locale
    # changing back to default shoves a blank string there
    locale.present? ? locale : SiteSetting.default_locale
  end

  # Creates open graph and twitter card meta data
  def crawlable_meta_data(opts = nil)
    opts ||= {}
    opts[:url] ||= "#{Discourse.base_url_no_prefix}#{request.fullpath}"

    if opts[:image].blank? && (SiteSetting.default_opengraph_image_url.present? || SiteSetting.twitter_summary_large_image_url.present?)
      opts[:twitter_summary_large_image] = SiteSetting.twitter_summary_large_image_url if SiteSetting.twitter_summary_large_image_url.present?
      opts[:image] = SiteSetting.default_opengraph_image_url.present? ? SiteSetting.default_opengraph_image_url : SiteSetting.twitter_summary_large_image_url
    elsif opts[:image].blank? && SiteSetting.apple_touch_icon_url.present?
      opts[:image] = SiteSetting.apple_touch_icon_url
    end

    # Use the correct scheme for open graph image
    if opts[:image].present?
      if opts[:image].start_with?("//")
        uri = URI(Discourse.base_url)
        opts[:image] = "#{uri.scheme}:#{opts[:image]}"
      elsif opts[:image].start_with?("/uploads/")
        opts[:image] = "#{Discourse.base_url}#{opts[:image]}"
      elsif GlobalSetting.relative_url_root && opts[:image].start_with?(GlobalSetting.relative_url_root)
        opts[:image] = "#{Discourse.base_url_no_prefix}#{opts[:image]}"
      end
    end

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
    @application_logo_url ||= (mobile_view? && SiteSetting.mobile_logo_url).presence || SiteSetting.logo_url
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

  def customization_disabled?
    request.env[ApplicationController::NO_CUSTOM]
  end

  def allow_plugins?
    !request.env[ApplicationController::NO_PLUGINS]
  end

  def allow_third_party_plugins?
    allow_plugins? && !request.env[ApplicationController::ONLY_OFFICIAL]
  end

  def normalized_safe_mode
    safe_mode = nil
    (safe_mode ||= []) << ApplicationController::NO_CUSTOM if customization_disabled?
    (safe_mode ||= []) << ApplicationController::NO_PLUGINS if !allow_plugins?
    (safe_mode ||= []) << ApplicationController::ONLY_OFFICIAL if !allow_third_party_plugins?
    if safe_mode
      safe_mode.join(",").html_safe
    end
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
    erbs.each { |erb| result << render(file: erb) }
    result.html_safe
  end

  def topic_featured_link_domain(link)
    begin
      uri = URI.encode(link)
      uri = URI.parse(uri)
      uri = URI.parse("http://#{uri}") if uri.scheme.nil?
      host = uri.host.downcase
      host.start_with?('www.') ? host[4..-1] : host
    rescue
      ''
    end
  end

  def theme_key
    if customization_disabled?
      nil
    else
      request.env[:resolved_theme_key]
    end
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
    lookup = Theme.lookup_field(theme_key, mobile_view? ? :mobile : :desktop, name)
    lookup.html_safe if lookup
  end

  def discourse_stylesheet_link_tag(name, opts = {})
    if opts.key?(:theme_key)
      key = opts[:theme_key] unless customization_disabled?
    else
      key = theme_key
    end

    Stylesheet::Manager.stylesheet_link_tag(name, 'all', key)
  end
end
