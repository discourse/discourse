# frozen_string_literal: true

class InvitedUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :invite, -> { unscope(where: :deleted_at) }

  validates_presence_of :invite_id
  validates_uniqueness_of :invite_id, scope: :user_id, conditions: -> { where.not(user_id: nil) }
end

# == Schema Information
#
# Table name: invited_users
#
#  id          :bigint           not null, primary key
#  user_id     :integer
#  invite_id   :integer          not null
#  redeemed_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_invited_users_on_invite_id              (invite_id)
#  index_invited_users_on_user_id_and_invite_id  (user_id,invite_id) UNIQUE WHERE (user_id IS NOT NULL)
#
