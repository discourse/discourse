# frozen_string_literal: true

module DiscourseId
  DEFAULT_PROVIDER_URL = "https://id.discourse.com"

  def self.provider_url
    SiteSetting.discourse_id_provider_url.presence || DEFAULT_PROVIDER_URL
  end
end
