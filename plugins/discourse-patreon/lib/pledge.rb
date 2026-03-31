# frozen_string_literal: true

module Patreon
  class Pledge
    def self.create!(data, adapter: ApiVersion.current)
      save!([data], true, adapter: adapter)
    end

    def self.update!(data, adapter: ApiVersion.current)
      delete!(data, adapter: adapter)
      create!(data, adapter: adapter)
    end

    def self.delete!(data, adapter: ApiVersion.current)
      entry = data["data"]
      reward_users = Patreon::RewardUser.all

      patron_id = adapter.delete_pledge_data(entry, reward_users)

      Patreon.set("pledges", all.except(patron_id))
      Decline.set(Decline.all.except(patron_id))
      Patreon.set("users", Patreon::Patron.all.except(patron_id))
      Patreon.set("reward-users", reward_users)
    end

    def self.save!(pledges_data, is_append = false, adapter: ApiVersion.current)
      pledges = is_append ? all : {}
      reward_users = is_append ? Patreon::RewardUser.all : {}
      users = is_append ? Patreon::Patron.all : {}
      declines = is_append ? Decline.all : {}

      pledges_data.each do |pledge_data|
        new_pledges, new_declines, new_reward_users, new_users = adapter.extract(pledge_data)

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

    def self.all
      Patreon.get("pledges") || {}
    end

    def self.get_patreon_id(data, adapter: ApiVersion.adapter_for_payload(data))
      adapter.get_patreon_id(data)
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
