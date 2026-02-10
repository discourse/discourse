# frozen_string_literal: true

module Patreon
  USER_DETAIL_FIELDS = %w[id amount_cents rewards declined_since].freeze

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Patreon
  end

  def self.show_donation_prompt_to_user?(user)
    return false unless SiteSetting.patreon_enabled && SiteSetting.patreon_donation_prompt_enabled?

    filter_group_ids = PatreonGroupRewardFilter.distinct.pluck(:group_id)
    (user.visible_groups.pluck(:id) & filter_group_ids).size <= 0
  end
end
