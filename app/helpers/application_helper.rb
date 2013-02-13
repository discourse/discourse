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
    defined?(Rack::MiniProfiler) and admin?
  end

  def admin?
    current_user.try(:admin?)
  end

end
