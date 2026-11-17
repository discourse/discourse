# frozen_string_literal: true

module Voice
  class ParticipantEvictor
    def self.evict!(room, user_id)
      Voice::AgentManager.evict!(room: room, user_id: user_id) if user_id.negative?

      session = close_session(room.id, user_id)
      Voice::ParticipantTracker.mark_left(room.id, user_id)
      Voice::ParticipantTracker.remove(room.id, user_id)

      user = User.find_by(id: user_id)
      Voice::UserStatusManager.clear_voice_status(user) if user

      Voice::BadgeGranterHooks.on_leave(user, session) if user
      Voice::RoomBroadcaster.publish_kick(room, user_id)
      Voice::RoomBroadcaster.publish_participants(room)

      Voice::Livekit::RoomServiceClient.remove_participant(room, user_id) unless user_id.negative?

      if Voice::ParticipantTracker.human_user_ids(room.id).empty? &&
           Voice::AgentManager.provider_room?(room.id)
        Voice::AgentManager.evict_agents_in_room!(room)
        Voice::RoomBroadcaster.publish_participants(room)
      end
    end

    def self.evict_unless_authorized!(room, user_id)
      return false if User.find_by(id: user_id)&.guardian&.can_join_voice_room?(room)

      evict!(room, user_id)
      true
    end

    def self.expel_unless_authorized!(livekit_room, identity)
      return false if !identity.match?(Voice::Livekit::RoomServiceClient::HUMAN_IDENTITY)

      room = Voice::Room.find_by(id: Voice::Livekit.room_id_from_name(livekit_room))
      return false if room.nil? || User.find_by(id: identity)&.guardian&.can_join_voice_room?(room)

      Voice::Livekit::RoomServiceClient.expel(livekit_room, identity)
      true
    end

    def self.evict_unauthorized!(room)
      return if !room.saved_change_to_public?(from: true, to: false)

      connected_user_ids(room).each { |user_id| evict_unless_authorized!(room, user_id) }
      Voice::AgentManager.reconcile(room)
    end

    def self.connected_user_ids(room)
      Voice::ParticipantTracker.human_user_ids(room.id) |
        Voice::ParticipantTracker.resuming_user_ids(room.id) |
        Voice::Livekit::RoomServiceClient.participant_user_ids(room)
    end
    private_class_method :connected_user_ids

    def self.close_session(room_id, user_id)
      metadata = Voice::ParticipantTracker.get_metadata(room_id, user_id)
      return unless metadata[:session_id]

      session = Voice::Session.find_by(id: metadata[:session_id])
      session&.close!
      session
    end
  end
end
