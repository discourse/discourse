# frozen_string_literal: true

module Jobs
  class CleanUpPostTimings < ::Jobs::Onceoff

    # Remove post timings that are remnants of previous post moves
    # or other shenanigans and don't reference a valid user or post anymore.
    def execute_onceoff(args)
      DB.exec <<~SQL
        DELETE
        FROM post_timings pt
        WHERE NOT EXISTS(
                SELECT 1
                FROM posts p
                WHERE p.topic_id = pt.topic_id
                  AND p.post_number = pt.post_number
            )
      SQL

      DB.exec <<~SQL
        DELETE
        FROM post_timings pt
        WHERE NOT EXISTS(
                SELECT 1
                FROM users u
                WHERE pt.user_id = u.id
            )
      SQL
    end
  end
end
