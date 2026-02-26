# frozen_string_literal: true

class PatreonPatronReward < ActiveRecord::Base
  belongs_to :patreon_patron
  belongs_to :patreon_reward
end

# == Schema Information
#
# Table name: patreon_patron_rewards
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  patreon_patron_id :bigint           not null
#  patreon_reward_id :bigint           not null
#
# Indexes
#
#  idx_patreon_patron_rewards_unique                  (patreon_patron_id,patreon_reward_id) UNIQUE
#  index_patreon_patron_rewards_on_patreon_patron_id  (patreon_patron_id)
#  index_patreon_patron_rewards_on_patreon_reward_id  (patreon_reward_id)
#
# Foreign Keys
#
#  fk_rails_...  (patreon_patron_id => patreon_patrons.id) ON DELETE => cascade
#  fk_rails_...  (patreon_reward_id => patreon_rewards.id) ON DELETE => cascade
#
