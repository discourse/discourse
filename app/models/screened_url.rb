# frozen_string_literal: true

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
    self.url = ScreenedUrl.normalize_url(url) if url
    self.domain = domain.downcase.sub(/\Awww\./, "") if domain
  end

  def self.watch(url, domain, opts = {})
    find_match(url) || create(opts.slice(:action_type, :ip_address).merge(url: url, domain: domain))
  end

  def self.find_match(url)
    find_by_url normalize_url(url)
  end

  def self.normalize_url(url)
    normalized = url.gsub(%r{http(s?)://}i, "")
    normalized.gsub!(%r{(/)+\z}, "") # trim trailing slashes
    normalized.gsub!(%r{\A([^/]+)(?:/)?}) { |m| m.downcase } # downcase the domain part of the url
    normalized
  end
end

# == Schema Information
#
# Table name: screened_urls
#
#  id            :integer          not null, primary key
#  action_type   :integer          not null
#  domain        :string           not null
#  ip_address    :inet
#  last_match_at :datetime
#  match_count   :integer          default(0), not null
#  url           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_screened_urls_on_last_match_at  (last_match_at)
#  index_screened_urls_on_url            (url) UNIQUE
#
