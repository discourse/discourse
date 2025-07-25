# frozen_string_literal: true

module ::DiscourseGamification
  class DirectoryIntegration
    def self.query
      <<~SQL
        WITH default_leaderboard AS (
          SELECT
            from_date,
            to_date
          FROM
            gamification_leaderboards
          ORDER BY
            id ASC
          LIMIT 1
        ), total_score AS (
          SELECT
            user_id,
            SUM(score) AS score
          FROM
            gamification_scores
          LEFT JOIN
            default_leaderboard ON true
          WHERE
            date >= :since
            AND
            (
              (
                default_leaderboard.from_date IS NULL
                OR
                date >= default_leaderboard.from_date
              )
              AND
              (
                default_leaderboard.to_date IS NULL
                OR
                date <= default_leaderboard.to_date
              )
            )
          GROUP BY
            1
        ), scored_directory AS (
          SELECT
            directory_items.user_id,
            COALESCE(total_score.score, 0) AS score
          FROM
            directory_items
          LEFT JOIN
            total_score ON total_score.user_id = directory_items.user_id
          WHERE
            directory_items.period_type = :period_type
        )
        UPDATE
          directory_items
        SET
          gamification_score = scored_directory.score
        FROM
          scored_directory
        WHERE
          scored_directory.user_id = directory_items.user_id AND
          directory_items.period_type = :period_type AND
          scored_directory.score != directory_items.gamification_score
      SQL
    end
  end
end
