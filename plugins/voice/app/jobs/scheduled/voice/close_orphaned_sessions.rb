# frozen_string_literal: true

module Jobs
  module Voice
    class CloseOrphanedSessions < ::Jobs::Scheduled
      every 5.minutes

      def execute(_args)
        return unless SiteSetting.voice_enabled && SiteSetting.voice_analytics_enabled

        participant_cache = {}

        ::Voice::Session.orphaned.find_each do |session|
          participant_ids =
            participant_cache[session.room_id] ||= ::Voice::ParticipantTracker.user_ids(
              session.room_id,
            )
          next if participant_ids.include?(session.user_id)

          left_at =
            ::Voice::ParticipantTracker.last_heartbeat_at(session.room_id, session.user_id) ||
              Time.current

          session.close!(at: left_at)
          ::Voice::ParticipantTracker.remove(session.room_id, session.user_id)

          user = User.find_by(id: session.user_id)
          ::Voice::BadgeGranterHooks.on_leave(user, session) if user
        end
      end
    end
  end
end
