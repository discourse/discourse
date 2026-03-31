# frozen_string_literal: true

module Patreon
  module ApiVersion
    module V1
      BASE_URL = "https://api.patreon.com"

      def self.campaign_data_url
        "/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page[count]=100"
      end

      def self.api_base_url
        BASE_URL
      end

      def self.token_base_url
        BASE_URL
      end

      def self.token_path
        "/oauth2/token"
      end

      def self.oauth_token_url
        "#{BASE_URL}/oauth2/token"
      end

      def self.oauth_authorize_params
        { response_type: "code" }
      end

      def self.oauth_identity_url
        "#{BASE_URL}/oauth2/api/current_user"
      end

      def self.parse_campaigns(response)
        rewards = {}
        campaign_rewards = []
        pledge_uris = []

        response["data"].each do |campaign|
          uri = campaign["relationships"]["pledges"]["links"]["first"]
          pledge_uris << uri.sub("page%5Bcount%5D=20", "page%5Bcount%5D=100")

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

        { rewards: rewards, pledge_uris: pledge_uris }
      end

      def self.pull_pledges!(campaign_data)
        uris = campaign_data[:pledge_uris].dup
        pledges_data = []

        uris.each do |uri|
          pledge_data = Patreon::Api.get(uri)

          if pledge_data["links"] && pledge_data["links"]["next"]
            next_page_uri = pledge_data["links"]["next"]
            uris << next_page_uri if next_page_uri.present?
          end

          pledges_data << pledge_data if pledge_data.present?
        end

        Patreon::Pledge.save!(pledges_data, adapter: self)
      end

      def self.extract(pledge_data)
        pledges, declines, reward_users, users = {}, {}, {}, {}

        if pledge_data && pledge_data["data"].present?
          pledge_data["data"] = [pledge_data["data"]] unless pledge_data["data"].kind_of?(Array)

          pledge_data["data"].each do |entry|
            if entry["type"] == "pledge"
              patron_id = entry["relationships"]["patron"]["data"]["id"]
              attrs = entry["attributes"]

              unless entry["relationships"]["reward"]["data"].nil?
                (reward_users[entry["relationships"]["reward"]["data"]["id"]] ||= []) << patron_id
              end
              pledges[patron_id] = attrs["amount_cents"]
              declines[patron_id] = attrs["declined_since"] if attrs["declined_since"].present?
            elsif entry["type"] == "member"
              patron_id = entry["relationships"]["user"]["data"]["id"]
              attrs = entry["attributes"]

              currently_entitled_tiers = entry["relationships"]["currently_entitled_tiers"] || {}
              (currently_entitled_tiers["data"] || []).each do |tier|
                (reward_users[tier["id"]] ||= []) << patron_id
              end
              pledges[patron_id] = attrs["pledge_amount_cents"]
              declines[patron_id] = attrs["last_charge_date"] if attrs["last_charge_status"] ==
                "Declined"
            end
          end

          pledge_data["included"]&.each do |entry|
            if entry["type"] == "user" && entry["attributes"]["email"].present?
              users[entry["id"]] = entry["attributes"]["email"].downcase
            end
          end
        end

        [pledges, declines, reward_users, users]
      end

      def self.delete_pledge_data(entry, reward_users)
        rel = entry["relationships"]

        if entry["type"] == "pledge"
          patron_id = rel["patron"]["data"]["id"]
          reward_id = rel["reward"]["data"]["id"] if rel["reward"]["data"].present?

          reward_users[reward_id].reject! { |i| i == patron_id } if reward_id.present?
        elsif entry["type"] == "member"
          patron_id = rel["user"]["data"]["id"]

          (rel.dig("currently_entitled_tiers", "data") || []).each do |tier|
            (reward_users[tier["id"]] || []).reject! { |i| i == patron_id }
          end
        end

        patron_id
      end

      def self.get_patreon_id(data)
        entry = data["data"]
        key = entry["type"] == "member" ? "user" : "patron"
        entry["relationships"][key]["data"]["id"]
      end

      def self.webhook_triggers
        %w[
          pledges:create
          pledges:update
          pledges:delete
          members:pledge:create
          members:pledge:update
          members:pledge:delete
        ]
      end
    end
  end
end
