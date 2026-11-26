# frozen_string_literal: true

module Live
  class RoomMembership < ActiveRecord::Base
    self.table_name = "#{Live.table_name_prefix}room_memberships"

    belongs_to :room, class_name: "Live::Room"
    belongs_to :user

    ROLE_PARTICIPANT = 0
    ROLE_MODERATOR = 1
    ROLE_SPEAKER = 2
    ROLES = {
      "participant" => ROLE_PARTICIPANT,
      "moderator" => ROLE_MODERATOR,
      "speaker" => ROLE_SPEAKER,
    }.freeze

    after_create :disconnect_direct_call_chat
    after_create_commit :broadcast_chat_disconnected

    scope :moderator, -> { where(role: ROLE_MODERATOR) }
    scope :speaker, -> { where(role: ROLE_SPEAKER) }

    def moderator?
      role == ROLE_MODERATOR
    end

    def participant?
      role == ROLE_PARTICIPANT
    end

    def speaker?
      role == ROLE_SPEAKER
    end

    def can_speak?
      moderator? || speaker?
    end

    def role_name
      ROLES.key(role) || "participant"
    end

    def self.role_value(key)
      return ROLE_PARTICIPANT if key.blank?

      ROLES[key.to_s] || ROLE_PARTICIPANT
    end

    validates :room_id, presence: true
    validates :user_id, presence: true, uniqueness: { scope: :room_id }

    private

    def disconnect_direct_call_chat
      return unless room.direct_call_chat?

      room.with_lock do
        if room.direct_call_chat? && !room.chat_channel.chatable.users.exists?(id: user_id)
          room.update!(chat_channel_id: nil)
          @chat_disconnected = true
        end
      end
    end

    def broadcast_chat_disconnected
      return unless @chat_disconnected

      Live::RoomBroadcaster.new(room).publish_room(type: "chat_disabled")
    end
  end
end

# == Schema Information
#
# Table name: live_room_memberships
#
#  id         :bigint           not null, primary key
#  role       :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  room_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_live_room_memberships_on_room_and_user  (room_id,user_id) UNIQUE
#  index_live_room_memberships_on_room_id      (room_id)
#  index_live_room_memberships_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (room_id => live_rooms.id)
#
