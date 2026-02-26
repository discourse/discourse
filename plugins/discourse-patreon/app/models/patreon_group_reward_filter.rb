# frozen_string_literal: true

class PatreonGroupRewardFilter < ActiveRecord::Base
  belongs_to :group
  belongs_to :patreon_reward
end

# == Schema Information
#
# Table name: patreon_group_reward_filters
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  group_id          :bigint           not null
#  patreon_reward_id :bigint           not null
#
# Indexes
#
#  idx_patreon_group_reward_filters_unique                  (group_id,patreon_reward_id) UNIQUE
#  index_patreon_group_reward_filters_on_group_id           (group_id)
#  index_patreon_group_reward_filters_on_patreon_reward_id  (patreon_reward_id)
#
# Foreign Keys
#
#  fk_rails_...  (group_id => groups.id) ON DELETE => cascade
#  fk_rails_...  (patreon_reward_id => patreon_rewards.id) ON DELETE => cascade
#
