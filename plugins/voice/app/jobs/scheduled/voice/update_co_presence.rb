# frozen_string_literal: true

module Jobs
  module Voice
    class UpdateCoPresence < ::Jobs::Scheduled
      every 5.minutes

      JOB_INTERVAL_SECONDS = 300
      GAP_THRESHOLD = 10.minutes

      def execute(_args)
        return unless SiteSetting.voice_enabled && SiteSetting.voice_analytics_enabled

        each_active_room do |room_id|
          # Bounded by the site capacity ceiling even if Redis holds strays,
          # since the pair count below grows quadratically.
          user_ids =
            ::Voice::ParticipantTracker
              .user_ids(room_id)
              .sort
              .first(SiteSetting.voice_max_room_participants)
          next if user_ids.size < 2

          today = Date.today

          # Block form: iterates the pairs without materializing them all.
          user_ids.combination(2) { |user_a, user_b| upsert_co_presence(user_a, user_b, today) }
        end
      end

      private

      def each_active_room(&block)
        pattern = "#{::Voice::ParticipantTracker::KEY_NAMESPACE}:*:participants"
        Discourse
          .redis
          .scan_each(match: pattern) do |key|
            yield Regexp.last_match(1).to_i if key =~ /voice:room:(\d+):participants/
          end
      end

      def upsert_co_presence(user_a, user_b, date)
        record =
          ::Voice::CoPresence.find_or_initialize_by(
            user_id_1: user_a,
            user_id_2: user_b,
            date: date,
          )

        gap = record.new_record? || record.updated_at < GAP_THRESHOLD.ago

        record.total_seconds += JOB_INTERVAL_SECONDS
        record.session_count += 1 if gap
        record.save!
      end
    end
  end
end
