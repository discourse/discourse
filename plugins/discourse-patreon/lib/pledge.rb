# frozen_string_literal: true

module Patreon
  class Pledge
    def self.create!(member_data)
      save!([member_data], true)
    end

    def self.update!(member_data)
      delete!(member_data)
      create!(member_data)
    end

    def self.delete!(member_data)
      entry = member_data["data"]
      rel = entry["relationships"]
      reward_users = Patreon::RewardUser.all

      patron_id = rel["user"]["data"]["id"]

      (rel.dig("currently_entitled_tiers", "data") || []).each do |tier|
        (reward_users[tier["id"]] || []).reject! { |i| i == patron_id }
      end

      Patreon.set("pledges", all.except(patron_id))
      Decline.set(Decline.all.except(patron_id))
      Patreon.set("users", Patreon::Patron.all.except(patron_id))
      Patreon.set("reward-users", reward_users)
    end

    def self.pull!(campaign_ids)
      members_data = []

      campaign_ids.each do |campaign_id|
        cursor = nil
        loop do
          response = Patreon::Api.members_data(campaign_id, cursor)
          break if response.blank? || response["data"].blank?

          members_data << response

          cursor = response.dig("meta", "pagination", "cursors", "next")
          break if cursor.blank?
        end
      end

      save!(members_data)
    end

    def self.save!(members_data, is_append = false)
      pledges = is_append ? all : {}
      reward_users = is_append ? Patreon::RewardUser.all : {}
      users = is_append ? Patreon::Patron.all : {}
      declines = is_append ? Decline.all : {}

      members_data.each do |member_data|
        new_pledges, new_declines, new_reward_users, new_users = extract(member_data)

        pledges.merge!(new_pledges)
        declines.merge!(new_declines)
        users.merge!(new_users)

        Patreon::Reward.all.keys.each do |key|
          reward_users[key] = (reward_users[key] || []) + (new_reward_users[key] || [])
        end
      end

      reward_users["0"] = pledges.keys

      Patreon.set("pledges", pledges)
      Decline.set(declines)
      Patreon.set("reward-users", reward_users)
      Patreon.set("users", users)
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
          case entry["type"]
          when "user"
            if entry["attributes"]["email"].present?
              users[entry["id"]] = entry["attributes"]["email"].downcase
            end
          end
        end
      end

      [pledges, declines, reward_users, users]
    end

    def self.all
      Patreon.get("pledges") || {}
    end

    def self.get_patreon_id(member_data)
      member_data["data"]["relationships"]["user"]["data"]["id"]
    end

    class Decline
      KEY = "pledge-declines"

      def self.all
        Patreon.get(KEY) || {}
      end

      def self.set(value)
        Patreon.set(KEY, value)
      end
    end
  end
end
