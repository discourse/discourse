# frozen_string_literal: true

module Patreon
  USER_DETAIL_FIELDS = %w[id amount_cents rewards declined_since].freeze

  module ApiVersion
    def self.current
      SiteSetting.patreon_api_version == "2" ? V2 : V1
    end

    def self.adapter_for_payload(data)
      data.dig("data", "type") == "pledge" ? V1 : V2
    end
  end

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Patreon
  end

  def self.store
    @store ||= PluginStore.new(PLUGIN_NAME)
  end

  def self.get(key)
    store.get(key)
  end

  def self.set(key, value)
    store.set(key, value)
  end

  def self.show_donation_prompt_to_user?(user)
    return false unless SiteSetting.patreon_donation_prompt_enabled?

    filters = get("filters") || {}
    filters = filters.keys.map(&:to_i)

    (user.visible_groups.pluck(:id) & filters).size <= 0
  end

  class Reward
    def self.all
      Patreon.get("rewards") || {}
    end
  end

  class RewardUser
    def self.all
      Patreon.get("reward-users") || {}
    end
  end
end
