# frozen_string_literal: true

class PatreonReward < ActiveRecord::Base
  has_many :patreon_patron_rewards, dependent: :destroy
  has_many :patreon_patrons, through: :patreon_patron_rewards
  has_many :patreon_group_reward_filters, dependent: :destroy
  has_many :groups, through: :patreon_group_reward_filters

  validates :patreon_id, presence: true, uniqueness: true
  validates :title, presence: true

  def self.to_hash
    all.each_with_object({}) do |r, h|
      h[r.patreon_id] = {
        "id" => r.patreon_id,
        "title" => r.title,
        "amount_cents" => r.amount_cents,
      }
    end
  end
end

# == Schema Information
#
# Table name: patreon_rewards
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          default(0), not null
#  title        :string(255)      not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  patreon_id   :string(255)      not null
#
# Indexes
#
#  index_patreon_rewards_on_patreon_id  (patreon_id) UNIQUE
#
