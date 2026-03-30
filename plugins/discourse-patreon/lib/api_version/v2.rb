# frozen_string_literal: true

module Patreon
  module ApiVersion
    module V2
      BASE_URL = "https://www.patreon.com"

      CAMPAIGN_FIELDS = "fields%5Bcampaign%5D=created_at,name,patron_count"
      TIER_FIELDS = "fields%5Btier%5D=title,amount_cents,created_at"
      MEMBER_FIELDS =
        "fields%5Bmember%5D=full_name,last_charge_date,last_charge_status,currently_entitled_amount_cents,patron_status,email"
      USER_FIELDS = "fields%5Buser%5D=email,full_name"

      def self.campaign_data_url
        "/api/oauth2/v2/campaigns?include=tiers,creator&#{CAMPAIGN_FIELDS}&#{TIER_FIELDS}"
      end

      def self.api_base_url
        BASE_URL
      end

      def self.token_base_url
        BASE_URL
      end

      def self.token_path
        "/api/oauth2/token"
      end

      def self.oauth_token_url
        "#{BASE_URL}/api/oauth2/token"
      end

      def self.oauth_authorize_params
        {
          response_type: "code",
          scope: "identity identity[email] campaigns campaigns.members campaigns.members[email]",
        }
      end

      def self.oauth_identity_url
        "#{BASE_URL}/api/oauth2/v2/identity?fields%5Buser%5D=email,full_name,is_email_verified"
      end

      def self.members_data_url(campaign_id, cursor = nil)
        url =
          "/api/oauth2/v2/campaigns/#{campaign_id}/members?include=currently_entitled_tiers,user&#{MEMBER_FIELDS}&#{USER_FIELDS}&#{TIER_FIELDS}&page%5Bcount%5D=1000"
        url += "&page%5Bcursor%5D=#{CGI.escape(cursor)}" if cursor.present?
        url
      end

      def self.parse_campaigns(response)
        rewards = {}

        campaign_ids = response["data"].map { |campaign| campaign["id"] }

        (response["included"] || []).each do |entry|
          if entry["type"] == "tier"
            id = entry["id"]
            rewards[id] = entry["attributes"]
            rewards[id]["id"] = id
          end
        end

        { rewards: rewards, campaign_ids: campaign_ids }
      end

      def self.pull_pledges!(campaign_data)
        campaign_ids = campaign_data[:campaign_ids]
        members_data = []

        campaign_ids.each do |campaign_id|
          cursor = nil
          loop do
            response = Patreon::Api.get(members_data_url(campaign_id, cursor))
            break if response.blank? || response["data"].blank?

            members_data << response

            cursor = response.dig("meta", "pagination", "cursors", "next")
            break if cursor.blank?
          end
        end

        Patreon::Pledge.save!(members_data, adapter: self)
      end

      def self.extract(member_data)
        pledges, declines, reward_users, users = {}, {}, {}, {}

        if member_data && member_data["data"].present?
          member_data["data"] = [member_data["data"]] unless member_data["data"].kind_of?(Array)

          member_data["data"].each do |entry|
            next unless entry["type"] == "member"

            patron_id = entry["relationships"]["user"]["data"]["id"]
            attrs = entry["attributes"]

            (entry.dig("relationships", "currently_entitled_tiers", "data") || []).each do |tier|
              (reward_users[tier["id"]] ||= []) << patron_id
            end

            pledges[patron_id] = attrs["currently_entitled_amount_cents"]
            declines[patron_id] = attrs["last_charge_date"] if attrs["last_charge_status"] ==
              "Declined"
          end

          (member_data["included"] || []).each do |entry|
            if entry["type"] == "user" && entry["attributes"]["email"].present?
              users[entry["id"]] = entry["attributes"]["email"].downcase
            end
          end
        end

        [pledges, declines, reward_users, users]
      end

      def self.delete_pledge_data(entry, reward_users)
        rel = entry["relationships"]
        patron_id = rel["user"]["data"]["id"]

        (rel.dig("currently_entitled_tiers", "data") || []).each do |tier|
          (reward_users[tier["id"]] || []).reject! { |i| i == patron_id }
        end

        patron_id
      end

      def self.get_patreon_id(data)
        data["data"]["relationships"]["user"]["data"]["id"]
      end

      def self.webhook_triggers
        %w[
          members:create
          members:update
          members:delete
          members:pledge:create
          members:pledge:update
          members:pledge:delete
        ]
      end
    end
  end
end
