# frozen_string_literal: true

module Voice
  class AdminRoomSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :slug,
               :description,
               :public,
               :max_participants,
               :room_type,
               :video_enabled,
               :livekit_enabled,
               :chat_channel_id,
               :chat_idle_minutes,
               :max_quality_profile,
               :member_count,
               :live_participant_count,
               :created_at,
               :updated_at

    has_one :creator, serializer: BasicUserSerializer, embed: :objects

    def room_type
      object.room_type_name
    end

    def max_quality_profile
      object.max_quality_profile_name
    end

    def member_count
      object.room_memberships.size
    end

    def live_participant_count
      Voice::ParticipantTracker.user_ids(object.id).size
    end
  end
end
