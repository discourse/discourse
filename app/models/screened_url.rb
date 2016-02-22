require_dependency 'screening_model'

# A ScreenedUrl record represents a URL that is being watched.
# If the URL is found in a post, some action can be performed.

# For now, nothing is done. We're just collecting the data and will decide
# what to do with it later.
class ScreenedUrl < ActiveRecord::Base

  include ScreeningModel

  default_action :do_nothing

  before_validation :normalize

  validates :url, presence: true, uniqueness: true
  validates :domain, presence: true

  def normalize
    self.url = ScreenedUrl.normalize_url(self.url) if self.url
    self.domain = self.domain.downcase.sub(/^www\./, '') if self.domain
  end

  def self.watch(url, domain, opts={})
    find_match(url) || create(opts.slice(:action_type, :ip_address).merge(url: url, domain: domain))
  end

  def self.find_match(url)
    find_by_url normalize_url(url)
  end

  def self.normalize_url(url)
    normalized = url.gsub(/http(s?):\/\//i, '')
    normalized.gsub!(/(\/)+$/, '') # trim trailing slashes
    normalized.gsub!(/^([^\/]+)(?:\/)?/) { |m| m.downcase } # downcase the domain part of the url
    normalized
  end
end

# == Schema Information
#
# Table name: screened_urls
#
#  id            :integer          not null, primary key
#  url           :string           not null
#  domain        :string           not null
#  action_type   :integer          not null
#  match_count   :integer          default(0), not null
#  last_match_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ip_address    :inet
#
# Indexes
#
#  index_screened_urls_on_last_match_at  (last_match_at)
#  index_screened_urls_on_url            (url) UNIQUE
#
