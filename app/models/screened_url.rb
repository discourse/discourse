require_dependency 'screening_model'

# A ScreenedUrl record represents a URL that is being watched.
# If the URL is found in a post, some action can be performed.

# For now, nothing is done. We're just collecting the data and will decide
# what to do with it later.
class ScreenedUrl < ActiveRecord::Base

  include ScreeningModel

  default_action :do_nothing

  before_validation :strip_http

  validates :url, presence: true, uniqueness: true
  validates :domain, presence: true

  def strip_http
    self.url.gsub!(/http(s?):\/\//i, '')
  end

  def self.watch(url, domain, opts={})
    find_by_url(url) || create(opts.slice(:action_type, :ip_address).merge(url: url, domain: domain))
  end
end
