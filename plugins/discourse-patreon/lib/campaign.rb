# frozen_string_literal: true

require "json"

module Patreon
  class Campaign
    def self.update!
      rewards = {}
      campaign_ids = []

      response = Patreon::Api.campaign_data

      return false if response.blank? || response["data"].blank?

      response["data"].each { |campaign| campaign_ids << campaign["id"] }

      (response["included"] || []).each do |entry|
        if entry["type"] == "tier"
          id = entry["id"]
          rewards[id] = entry["attributes"]
          rewards[id]["id"] = id
        end
      end

      # Special catch all patrons virtual reward
      rewards["0"] ||= {}
      rewards["0"]["title"] = "All Patrons"
      rewards["0"]["amount_cents"] = 0

      Patreon.set("rewards", rewards)

      Patreon::Pledge.pull!(campaign_ids)

      # Sets all patrons to the seed group by default on first run
      filters = Patreon.get("filters")
      Patreon::Seed.seed_content! if filters.blank?

      true
    end
  end
end
