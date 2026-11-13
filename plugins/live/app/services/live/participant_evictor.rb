# frozen_string_literal: true

module Live
  class ParticipantEvictor
    def self.evict!(room, user_id)
      Live::AgentManager.evict!(room: room, user_id: user_id) if user_id.negative?

      session = close_session(room.id, user_id)
      Live::ParticipantTracker.mark_left(room.id, user_id)
      Live::ParticipantTracker.remove(room.id, user_id)

      user = User.find_by(id: user_id)
      Live::UserStatusManager.clear_live_status(user) if user

      Live::BadgeGranterHooks.on_leave(user, session) if user
      Live::RoomBroadcaster.publish_kick(room, user_id)
      Live::RoomBroadcaster.publish_participants(room)

      Live::Livekit::RoomServiceClient.remove_participant(room, user_id) unless user_id.negative?

      if Live::ParticipantTracker.human_user_ids(room.id).empty? &&
           Live::AgentManager.provider_room?(room.id)
        Live::AgentManager.evict_agents_in_room!(room)
        Live::RoomBroadcaster.publish_participants(room)
      end
    end

    def self.evict_unless_authorized!(room, user_id)
      return false if User.find_by(id: user_id)&.guardian&.can_join_live_room?(room)

      evict!(room, user_id)
      true
    end

    def self.expel_unless_authorized!(livekit_room, identity)
      return false if !identity.match?(Live::Livekit::RoomServiceClient::HUMAN_IDENTITY)

      room = Live::Room.find_by(id: Live::Livekit.room_id_from_name(livekit_room))
      return false if room.nil? || User.find_by(id: identity)&.guardian&.can_join_live_room?(room)

      Live::Livekit::RoomServiceClient.expel(livekit_room, identity)
      true
    end

    def self.evict_unauthorized!(room)
      return if !room.saved_change_to_public?(from: true, to: false)

      connected_user_ids(room).each { |user_id| evict_unless_authorized!(room, user_id) }
      Live::AgentManager.reconcile(room)
    end

    def self.connected_user_ids(room)
      Live::ParticipantTracker.human_user_ids(room.id) |
        Live::ParticipantTracker.resuming_user_ids(room.id) |
        Live::Livekit::RoomServiceClient.participant_user_ids(room)
    end
    private_class_method :connected_user_ids

    def self.close_session(room_id, user_id)
      metadata = Live::ParticipantTracker.get_metadata(room_id, user_id)
      return unless metadata[:session_id]

      session = Live::Session.find_by(id: metadata[:session_id])
      session&.close!
      session
    end
  end
end
