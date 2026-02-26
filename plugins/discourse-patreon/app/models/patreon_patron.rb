# frozen_string_literal: true

class PatreonPatron < ActiveRecord::Base
  has_many :patreon_patron_rewards, dependent: :destroy
  has_many :patreon_rewards, through: :patreon_patron_rewards

  validates :patreon_id, presence: true, uniqueness: true
end

# == Schema Information
#
# Table name: patreon_patrons
#
#  id             :bigint           not null, primary key
#  amount_cents   :integer
#  declined_since :datetime
#  email          :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  patreon_id     :string(255)      not null
#
# Indexes
#
#  index_patreon_patrons_on_email       (email)
#  index_patreon_patrons_on_patreon_id  (patreon_id) UNIQUE
#
