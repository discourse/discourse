require 'current_user'
require 'canonical_url'
require_dependency 'guardian'
require_dependency 'unread'
require_dependency 'age_words'

module ApplicationHelper
  include CurrentUser
  include CanonicalURL::Helpers

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

  # Creates open graph and twitter card meta data
  def crawlable_meta_data(opts=nil)

    opts ||= {}
    opts[:image] ||= "#{Discourse.base_url}#{SiteSetting.logo_small_url}"
    opts[:url] ||= "#{Discourse.base_url}#{request.fullpath}"

    # Add opengraph tags
    result =  tag(:meta, property: 'og:site_name', content: SiteSetting.title) << "\n"

    result << tag(:meta, name: 'twitter:card', content: "summary")
    [:image, :url, :title, :description].each do |property|
      if opts[property].present?
        escape = (property != :image)
        result << tag(:meta, {property: "og:#{property}", content: opts[property]}, nil, escape) << "\n"
        result << tag(:meta, {name: "twitter:#{property}", content: opts[property]}, nil, escape) << "\n"
      end
    end

    result
  end

  def markdown_content(key, replacements=nil)
    PrettyText.cook(SiteContent.content_for(key, replacements || {})).html_safe
  end

  def faq_path
    return "#{Discourse::base_uri}/faq"
  end

  def tos_path
    SiteSetting.tos_url.blank? ? "#{Discourse::base_uri}/tos" : SiteSetting.tos_url
  end

  def privacy_path
    SiteSetting.privacy_policy_url.blank? ? "#{Discourse::base_uri}/privacy" : SiteSetting.privacy_policy_url
  end

  def login_path
    return "#{Discourse::base_uri}/login"
  end
end
