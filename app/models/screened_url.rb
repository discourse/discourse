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
    if self.url
      self.url.gsub!(/http(s?):\/\//i, '')
      self.url.gsub!(/(\/)+$/, '') # trim trailing slashes
    end
  end

  def self.watch(url, domain, opts={})
    find_by_url(url) || create(opts.slice(:action_type, :ip_address).merge(url: url, domain: domain))
  end
end

# == Schema Information
#
# Table name: screened_urls
#
#  id            :integer          not null, primary key
#  url           :string(255)      not null
#  domain        :string(255)      not null
#  action_type   :integer          not null
#  match_count   :integer          default(0), not null
#  last_match_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ip_address    :string
#
# Indexes
#
#  index_screened_urls_on_last_match_at  (last_match_at)
#  index_screened_urls_on_url            (url) UNIQUE
#

