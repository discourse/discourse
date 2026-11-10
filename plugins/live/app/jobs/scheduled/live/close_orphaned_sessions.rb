# frozen_string_literal: true

module Jobs
  module Live
    class CloseOrphanedSessions < ::Jobs::Scheduled
      every 5.minutes

      def execute(_args)
        return unless SiteSetting.live_enabled && SiteSetting.live_analytics_enabled

        participant_cache = {}
        transport_cache = {}

        ::Live::Session.orphaned.find_each do |session|
          participant_ids =
            participant_cache[session.room_id] ||= ::Live::ParticipantTracker.user_ids(
              session.room_id,
            )
          next if participant_ids.include?(session.user_id)
          # Lapsed presence with a resumable participant session is most likely
          # a mesh client cut off by an outage, not one that left. LiveKit
          # reports departures itself and resumes through its own token ladder.
          transport =
            transport_cache.fetch(session.room_id) do
              transport_cache[session.room_id] = ::Live::ParticipantTracker.pinned_transport(
                session.room_id,
              )
            end
          if transport != "livekit" &&
               ::Live::ParticipantTracker.participant_session?(session.room_id, session.user_id)
            next
          end

          left_at =
            ::Live::ParticipantTracker.last_heartbeat_at(session.room_id, session.user_id) ||
              Time.current

          session.close!(at: left_at)
          ::Live::ParticipantTracker.remove(session.room_id, session.user_id)

          room = ::Live::Room.find_by(id: session.room_id)
          if room && ::Live::ParticipantTracker.vacant?(room.id)
            ::Live::AgentManager.evict_agents_in_room!(room)
          end

          user = User.find_by(id: session.user_id)
          ::Live::BadgeGranterHooks.on_leave(user, session) if user
        end
      end
    end
  end
end
