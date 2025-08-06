# frozen_string_literal: true

require "json"

module ::Patreon
  class Tokens
    def self.update!
      conn = Faraday.new(url: "https://api.patreon.com")

      response =
        conn.post(
          "/oauth2/token",
          grant_type: "refresh_token",
          refresh_token: SiteSetting.patreon_creator_refresh_token,
          client_id: SiteSetting.patreon_client_id,
          client_secret: SiteSetting.patreon_client_secret,
        )

      if response.status == 200
        tokens = JSON.parse response.body
        SiteSetting.patreon_creator_access_token = tokens["access_token"]
        SiteSetting.patreon_creator_refresh_token = tokens["refresh_token"]
      else
        Rails.logger.warn(
          "Patreon token refresh failed with status: #{response.status}.\n\n #{response.body}",
        )
      end
    end
  end
end
