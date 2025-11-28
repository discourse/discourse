# frozen_string_literal: true

module DiscourseId
  DEFAULT_PROVIDER_URL = "https://id.discourse.com"

  def self.provider_url
    SiteSetting.discourse_id_provider_url.presence || DEFAULT_PROVIDER_URL
  end

  def self.masked_client_id
    client_id = SiteSetting.discourse_id_client_id

    return if client_id.blank?

    client_id.size <= 12 ? client_id : "#{client_id[..7]}...#{client_id[-4..]}"
  end
end
