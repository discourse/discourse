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

  def crawlable_meta_data(url, title, description)
    # Image to supply as meta data
    image = "#{Discourse.base_url}#{SiteSetting.logo_url}"

    # Add opengraph tags
    result =  tag(:meta, property: 'og:site_name', content: SiteSetting.title) << "\n"
    result << tag(:meta, property: 'og:image', content: image) << "\n"
    result << tag(:meta, property: 'og:url', content: url) << "\n"
    result << tag(:meta, property: 'og:title', content: title) << "\n"
    result << tag(:meta, property: 'og:description', content: description) << "\n"

    # Add twitter card
    result << tag(:meta, property: 'twitter:card', content: "summary") << "\n"
    result << tag(:meta, property: 'twitter:url', content: url) << "\n"
    result << tag(:meta, property: 'twitter:title', content: title) << "\n"
    result << tag(:meta, property: 'twitter:description', content: description) << "\n"
    result << tag(:meta, property: 'twitter:image', content: image) << "\n"

    result
  end

end
