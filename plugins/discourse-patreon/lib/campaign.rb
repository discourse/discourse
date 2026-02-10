# frozen_string_literal: true

require "json"

module Patreon
  class Campaign
    def self.update!
      rewards = {}
      campaign_rewards = []
      pledges_uris = []

      response = Patreon::Api.campaign_data

      return false if response.blank? || response["data"].blank?

      response["data"].each do |campaign|
        uri = campaign["relationships"]["pledges"]["links"]["first"]
        pledges_uris << uri.sub("page%5Bcount%5D=20", "page%5Bcount%5D=100")

        campaign["relationships"]["rewards"]["data"].each do |entry|
          campaign_rewards << entry["id"]
        end
      end

      response["included"].each do |entry|
        id = entry["id"]
        if entry["type"] == "reward" && campaign_rewards.include?(id)
          rewards[id] = entry["attributes"]
          rewards[id]["id"] = id
        end
      end

      # Special catch all patrons virtual reward
      rewards["0"] ||= {}
      rewards["0"]["title"] = "All Patrons"
      rewards["0"]["amount_cents"] = 0

      # Upsert rewards into database
      now = Time.zone.now
      reward_rows =
        rewards.map do |patreon_id, attrs|
          {
            patreon_id: patreon_id,
            title: attrs["title"] || "Untitled",
            amount_cents: attrs["amount_cents"].to_i,
            created_at: now,
            updated_at: now,
          }
        end

      if reward_rows.present?
        PatreonReward.upsert_all(
          reward_rows,
          unique_by: :patreon_id,
          update_only: %i[title amount_cents],
        )
      end

      # Prune stale rewards not in the current API response, but only those
      # without admin-configured group filters to avoid losing config data
      # on transient API inconsistencies.
      current_patreon_ids = rewards.keys
      stale_rewards = PatreonReward.where.not(patreon_id: current_patreon_ids)
      stale_without_filters =
        stale_rewards.where.not(id: PatreonGroupRewardFilter.select(:patreon_reward_id))
      stale_without_filters.destroy_all

      Patreon::Pledge.pull!(pledges_uris)

      # Sets all patrons to the seed group by default on first run
      Patreon::Seed.seed_content! unless PatreonGroupRewardFilter.exists?

      true
    end
  end
end
