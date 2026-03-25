# frozen_string_literal: true

require "json"

module Patreon
  class Campaign
    def self.update!
      adapter = ApiVersion.current
      response = Patreon::Api.campaign_data

      return false if response.blank? || response["data"].blank?

      campaign_data = adapter.parse_campaigns(response)
      rewards = campaign_data[:rewards]

      # Special catch all patrons virtual reward
      rewards["0"] ||= {}
      rewards["0"]["title"] = "All Patrons"
      rewards["0"]["amount_cents"] = 0

      Patreon.set("rewards", rewards)

      adapter.pull_pledges!(campaign_data)

      # Sets all patrons to the seed group by default on first run
      filters = Patreon.get("filters")
      Patreon::Seed.seed_content! if filters.blank?

      true
    end
  end
end
