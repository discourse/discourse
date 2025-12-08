# frozen_string_literal: true

module DiscourseRewind
  module Action
    class WritingAnalysis < BaseReport
      FakeData = {
        data: {
          total_words: 45_230,
          total_posts: 197,
          average_post_length: 230,
          readability_score: 65.4,
        },
        identifier: "writing-analysis",
      }

      def call
        return FakeData if should_use_fake_data?

        total_words =
          DB.query_single(<<~SQL, user_id: user.id, date_start: date.first, date_end: date.last)
          SELECT SUM(word_count) FROM posts
          WHERE user_id = :user_id
          AND created_at BETWEEN :date_start AND :date_end
          AND deleted_at IS NULL
        SQL

        post_count =
          DB.query_single(<<~SQL, user_id: user.id, date_start: date.first, date_end: date.last)
          SELECT COUNT(*) FROM posts
          WHERE user_id = :user_id
          AND created_at BETWEEN :date_start AND :date_end
          AND deleted_at IS NULL
        SQL

        average_post_length =
          post_count.first > 0 ? (total_words.first.to_f / post_count.first).round(2) : 0

        # Calculated using the Flesch Reading Ease formula,
        # with an approximation for syllables since this can
        # be tricky to get right in SQL.
        #
        # Tries to handle short sentences or ones without delmiters
        # and ending with emojis by treating them as a single sentence.
        readability_score =
          DB.query_single(<<~SQL, user_id: user.id, start: date.first, end: date.last)
          WITH cleaned AS (
            SELECT
              p.id AS post_id,
              p.user_id,
              p.created_at,
              p.word_count,
              regexp_replace(p.cooked, '<[^>]+>', ' ', 'g') AS plain
            FROM posts p
            WHERE p.user_id = :user_id
              AND p.created_at BETWEEN :start AND :end
          ),
          metrics AS (
            SELECT
              post_id,
              user_id,
              created_at,
              plain,
              word_count AS words,
              regexp_count(plain, '[.!?;:](\s|$)')                   AS sentences_raw,
              regexp_count(lower(plain), '[aeiouy]+')                AS syllables
            FROM cleaned
          ),
          scores AS (
            SELECT
              post_id,
              user_id,
              created_at,
              words,
              syllables,
              plain,

              CASE
                WHEN sentences_raw = 0 AND words > 5 THEN 1
                ELSE sentences_raw
              END AS sentences_fixed,

              -- Flesch Reading Ease formula
              CASE
                WHEN words = 0 THEN NULL
                WHEN (CASE WHEN sentences_raw = 0 AND words > 5 THEN 1 ELSE sentences_raw END) = 0 THEN NULL
                ELSE (
                  206.835
                  - 1.015 * (
                      words::float /
                      (CASE WHEN sentences_raw = 0 AND words > 5 THEN 1 ELSE sentences_raw END)
                    )
                  - 84.6  * (syllables::float / words)
                )
              END AS readability_score

            FROM metrics
          )
          SELECT AVG(readability_score) AS avg_readability_score
          FROM scores
          GROUP BY user_id;
        SQL

        {
          data: {
            total_words: total_words.first,
            total_posts: post_count.first,
            average_post_length: average_post_length,
            readability_score: readability_score.first,
          },
          identifier: "writing-analysis",
        }
      end
    end
  end
end
