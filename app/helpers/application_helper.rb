require 'current_user'
require 'canonical_url'
require_dependency 'guardian'
require_dependency 'unread'
require_dependency 'age_words'
require_dependency 'configurable_urls'
require_dependency 'mobile_detection'
require_dependency 'category_badge'
require_dependency 'global_path'
require_dependency 'canonical_url'

module ApplicationHelper
  include CurrentUser
  include CanonicalURL::Helpers
  include ConfigurableUrls
  include GlobalPath

  def ga_universal_json
    cookie_domain = SiteSetting.ga_universal_domain_name.gsub(/^http(s)?:\/\//, '')
    result = {cookieDomain: cookie_domain}
    if current_user.present?
      result[:userId] = current_user.id
    end
    result.to_json.html_safe
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

  def script(*args)
    if SiteSetting.enable_cdn_js_debugging && GlobalSetting.cdn_url
      tags = javascript_include_tag(*args, "crossorigin" => "anonymous")
      tags.gsub!("/assets/", "/cdn_asset/#{Discourse.current_hostname.gsub(".","_")}/")
      tags.gsub!(".js\"", ".js?v=1&origin=#{CGI.escape request.base_url}\"")
      tags.html_safe
    else
      javascript_include_tag(*args)
    end
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
    PrettyText.unescape_emoji(title)
    strip_tags(title)
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
    ["ar", "fa_IR", "he"].include? I18n.locale.to_s
  end

  def user_locale
    locale = current_user.locale if current_user && SiteSetting.allow_user_locale
    # changing back to default shoves a blank string there
    locale.present? ? locale : SiteSetting.default_locale
  end

  # Creates open graph and twitter card meta data
  def crawlable_meta_data(opts=nil)
    opts ||= {}
    opts[:url] ||= "#{Discourse.base_url_no_prefix}#{request.fullpath}"

    # Use the correct scheme for open graph
    if opts[:image].present? && opts[:image].start_with?("//")
      uri = URI(Discourse.base_url)
      opts[:image] = "#{uri.scheme}:#{opts[:image]}"
    elsif opts[:image].present? && opts[:image].start_with?("/uploads/")
      opts[:image] = "#{Discourse.base_url}#{opts[:image]}"
    end

    # Add opengraph tags
    result = []
    result << tag(:meta, property: 'og:site_name', content: SiteSetting.title)
    result << tag(:meta, name: 'twitter:card', content: "summary")

    [:url, :title, :description, :image].each do |property|
      if opts[property].present?
        escape = (property != :image)
        result << tag(:meta, { property: "og:#{property}", content: opts[property] }, nil, escape)
        result << tag(:meta, { name: "twitter:#{property}", content: opts[property] }, nil, escape)
      end
    end

    if opts[:read_time] && opts[:read_time] > 0 && opts[:like_count] && opts[:like_count] > 0
      result << tag(:meta, name: 'twitter:label1', value: I18n.t("reading_time"))
      result << tag(:meta, name: 'twitter:data1', value: "#{opts[:read_time]} mins 🕑")
      result << tag(:meta, name: 'twitter:label2', value: I18n.t("likes"))
      result << tag(:meta, name: 'twitter:data2', value: "#{opts[:like_count]} ❤")
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

  def application_logo_url
    @application_logo_url ||= (mobile_view? && SiteSetting.mobile_logo_url) || SiteSetting.logo_url
  end

  def login_path
    "#{Discourse::base_uri}/login"
  end

  def mobile_view?
    MobileDetection.resolve_mobile_view!(request.user_agent,params,session)
  end

  def crawler_layout?
    controller.try(:use_crawler_layout?)
  end

  def include_crawler_content?
    crawler_layout? || !mobile_view?
  end

  def mobile_device?
    MobileDetection.mobile_device?(request.user_agent)
  end

  def customization_disabled?
    session[:disable_customization]
  end

  def loading_admin?
    controller.class.name.split("::").first == "Admin"
  end

  def category_badge(category, opts=nil)
    CategoryBadge.html_for(category, opts).html_safe
  end

  def self.all_connectors
    @all_connectors = Dir.glob("plugins/*/app/views/connectors/**/*.html.erb")
  end

  def server_plugin_outlet(name)

    # Don't evaluate plugins in test
    return "" if Rails.env.test?

    matcher = Regexp.new("/connectors/#{name}/.*\.html\.erb$")
    erbs = ApplicationHelper.all_connectors.select {|c| c =~ matcher }
    return "" if erbs.blank?

    result = ""
    erbs.each {|erb| result << render(file: erb) }
    result.html_safe
  end

end
