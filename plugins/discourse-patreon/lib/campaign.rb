# frozen_string_literal: true

require "json"

module Patreon
  class Campaign
    def self.update!
      verbose = SiteSetting.patreon_verbose_log
      adapter = ApiVersion.current

      if verbose
        Rails.logger.warn("Patreon sync started using API v#{SiteSetting.patreon_api_version}")
      end

      response = Patreon::Api.campaign_data

      if response.blank? || response["data"].blank?
        Rails.logger.warn("Patreon sync: no campaign data returned") if verbose
        return false
      end

      campaign_data = adapter.parse_campaigns(response)
      rewards = campaign_data[:rewards]

      if verbose
        Rails.logger.warn(
          "Patreon sync: found #{rewards.size} rewards/tiers across #{response["data"].size} campaigns",
        )
      end

      # Special catch all patrons virtual reward
      rewards["0"] ||= {}
      rewards["0"]["title"] = "All Patrons"
      rewards["0"]["amount_cents"] = 0

      Patreon.set("rewards", rewards)

      adapter.pull_pledges!(campaign_data)

      pledges = Patreon.get("pledges") || {}
      users = Patreon.get("users") || {}
      if verbose
        Rails.logger.warn(
          "Patreon sync complete: #{pledges.size} pledges, #{users.size} users synced",
        )
      end

      # Sets all patrons to the seed group by default on first run
      filters = Patreon.get("filters")
      Patreon::Seed.seed_content! if filters.blank?

      true
    end
  end
end
