require 'current_user'
require 'canonical_url'
require_dependency 'guardian'
require_dependency 'unread'
require_dependency 'age_words'
require_dependency 'configurable_urls'
require_dependency 'mobile_detection'

module ApplicationHelper
  include CurrentUser
  include CanonicalURL::Helpers
  include ConfigurableUrls

  def script(*args)
    if SiteSetting.enable_cdn_js_debugging && GlobalSetting.cdn_url
      tags = javascript_include_tag(*args, "crossorigin" => "anonymous")
      tags.gsub!("/assets/", "/cdn_asset/#{Discourse.current_hostname.gsub(".","_")}/")
      tags.gsub!(".js\"", ".js?origin=#{CGI.escape request.base_url}\"")
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
    "#{mobile_view? ? 'mobile-view' : 'desktop-view'} #{mobile_device? ? 'mobile-device' : 'not-mobile-device'}"
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

  # Creates open graph and twitter card meta data
  def crawlable_meta_data(opts=nil)

    opts ||= {}
    opts[:image] ||= "#{Discourse.base_url}#{SiteSetting.logo_small_url}"
    opts[:url] ||= "#{Discourse.base_url}#{request.fullpath}"

    # Add opengraph tags
    result =  tag(:meta, property: 'og:site_name', content: SiteSetting.title) << "\n"

    result << tag(:meta, name: 'twitter:card', content: "summary")
    [:image, :url, :title, :description, 'image:width', 'image:height'].each do |property|
      if opts[property].present?
        escape = (property != :image)
        result << tag(:meta, {property: "og:#{property}", content: opts[property]}, nil, escape) << "\n"
        result << tag(:meta, {name: "twitter:#{property}", content: opts[property]}, nil, escape) << "\n"
      end
    end

    result
  end

  # Look up site content for a key. If the key is blank, you can supply a block and that
  # will be rendered instead.
  def markdown_content(key, replacements=nil)
    result = PrettyText.cook(SiteContent.content_for(key, replacements || {})).html_safe
    if result.blank? && block_given?
      yield
      nil
    else
      result
    end
  end

  def login_path
    "#{Discourse::base_uri}/login"
  end

  def mobile_view?
    MobileDetection.resolve_mobile_view!(request.user_agent,params,session)
  end

  def mobile_device?
    MobileDetection.mobile_device?(request.user_agent)
  end

  def customization_disabled?
    controller.class.name.split("::").first == "Admin" || session[:disable_customization]
  end


end
