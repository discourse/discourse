# frozen_string_literal: true

class InvitedUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :invite, -> { unscope(where: :deleted_at) }

  validates :invite_id, presence: true
  validates :invite_id, uniqueness: { scope: :user_id, conditions: -> { where.not(user_id: nil) } }

  after_destroy :decrement_invite_redemption_count

  private

  def decrement_invite_redemption_count
    return if invite_id.blank?

    Invite.unscoped.where(id: invite_id).where("redemption_count > 0").update_all(
      "redemption_count = redemption_count - 1",
    )
  end
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
