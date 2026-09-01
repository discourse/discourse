# frozen_string_literal: true

module Voice
  class Session < ActiveRecord::Base
    # A session's recorded end can be far later than the user's actual leave —
    # the orphan sweep stamps left_at when it finally runs, and until then an
    # abandoned session is open-ended — so any single shared interval is
    # capped at a plausible call length to keep phantom days out of the sums.
    MAX_COMPANION_OVERLAP_SECONDS = 12.hours.to_i

    # Matches the co-presence badge threshold: less than five minutes together
    # is a brush, not a shared session worth suggesting.
    MIN_COMPANION_OVERLAP_SECONDS = 5.minutes.to_i

    self.table_name = "#{Voice.table_name_prefix}sessions"

    # optional: sessions are history and outlive both their room's and their
    # user's deletion — close! must still work on a session whose room or
    # user is gone.
    belongs_to :user, optional: true
    belongs_to :room, class_name: "Voice::Room", optional: true

    scope :orphaned, -> { where(left_at: nil) }

    # People who shared time in this room with the user, most time together
    # first. Overlap is computed pairwise from session intervals; a session
    # still in progress counts up to now.
    class << self
      def top_room_companions_for(user_id, room_id, since:, limit: 10)
        overlap_seconds = <<~SQL
          LEAST(
            EXTRACT(
              EPOCH FROM (
                LEAST(COALESCE(mine.left_at, CURRENT_TIMESTAMP), COALESCE(theirs.left_at, CURRENT_TIMESTAMP)) -
                GREATEST(mine.joined_at, theirs.joined_at)
              )
            ),
            :max_overlap
          )
        SQL

        DB.query(
          <<~SQL,
            SELECT theirs.user_id AS companion_id,
                   SUM(#{overlap_seconds})::bigint AS total_seconds,
                   MAX(GREATEST(mine.joined_at, theirs.joined_at)) AS last_together_at
            FROM voice_sessions mine
            JOIN voice_sessions theirs
              ON theirs.room_id = mine.room_id
             AND theirs.user_id <> mine.user_id
             AND theirs.joined_at < COALESCE(mine.left_at, CURRENT_TIMESTAMP)
             AND mine.joined_at < COALESCE(theirs.left_at, CURRENT_TIMESTAMP)
            WHERE mine.user_id = :user_id
              AND mine.room_id = :room_id
              AND mine.joined_at >= :since
            GROUP BY theirs.user_id
            HAVING SUM(#{overlap_seconds}) >= :min_total
            ORDER BY total_seconds DESC, last_together_at DESC
            LIMIT :limit
          SQL
          user_id: user_id.to_i,
          room_id: room_id.to_i,
          since: since,
          limit: limit,
          max_overlap: MAX_COMPANION_OVERLAP_SECONDS,
          min_total: MIN_COMPANION_OVERLAP_SECONDS,
        )
      end
    end

    def close!(at: Time.current)
      update!(left_at: at)
    end
  end
end

# == Schema Information
#
# Table name: voice_sessions
#
#  id         :bigint           not null, primary key
#  joined_at  :datetime         not null
#  left_at    :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  room_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_voice_sessions_orphaned                                (left_at) WHERE (left_at IS NULL)
#  index_voice_sessions_on_room_id                            (room_id)
#  index_voice_sessions_on_room_id_and_joined_at              (room_id,joined_at)
#  index_voice_sessions_on_user_id                            (user_id)
#  index_voice_sessions_on_user_id_and_joined_at              (user_id,joined_at)
#  index_voice_sessions_on_user_id_and_room_id_and_joined_at  (user_id,room_id,joined_at)
#
