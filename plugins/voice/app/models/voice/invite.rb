# frozen_string_literal: true

module Voice
  class Invite < ActiveRecord::Base
    self.table_name = "#{Voice.table_name_prefix}invites"

    SOURCES = { notification: 0, link: 1 }

    # History rows, like sessions: they outlive their room and users.
    belongs_to :room, optional: true
    belongs_to :user, optional: true
    belongs_to :invited_by, class_name: "User", optional: true

    validates :user_id, comparison: { other_than: :invited_by_id }

    scope :redeemed, -> { where.not(redeemed_at: nil) }

    # A join that followed an invite — a notification and a shared link both
    # carry the inviter's username. Returns the invite only on its first
    # redemption, so the inviter is credited at most once per invitee per room.
    class << self
      def redeem!(room:, user:, inviter_username:)
        inviter = User.find_by(username_lower: inviter_username.to_s.downcase)
        return if inviter.nil? || inviter.id == user.id

        invite =
          create_or_find_by(room_id: room.id, user_id: user.id, invited_by_id: inviter.id) do |i|
            i.source = SOURCES[:link]
          end
        return if invite.redeemed_at.present?

        invite.update!(redeemed_at: Time.current)
        invite
      end
    end
  end
end

# == Schema Information
#
# Table name: voice_invites
#
#  id            :bigint           not null, primary key
#  redeemed_at   :datetime
#  source        :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  invited_by_id :bigint           not null
#  room_id       :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  idx_voice_invites_redeemed                                    (invited_by_id,user_id) WHERE (redeemed_at IS NOT NULL)
#  index_voice_invites_on_room_id_and_user_id_and_invited_by_id  (room_id,user_id,invited_by_id) UNIQUE
#  index_voice_invites_on_user_id_and_room_id                    (user_id,room_id)
#
