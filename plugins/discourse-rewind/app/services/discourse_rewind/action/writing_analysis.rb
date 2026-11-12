# frozen_string_literal: true

module DiscourseRewind
  module Action
    class WritingAnalysis < BaseReport
      MINIMUM_WORDS = 100
      MINIMUM_POSTS = 5

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

        posts = Post.joins(:topic).where(user_id: user.id, created_at: date)
        total_words, total_posts =
          posts.pick(Arel.sql("COALESCE(SUM(posts.word_count), 0)"), Arel.sql("COUNT(*)"))

        return if total_words < MINIMUM_WORDS || total_posts < MINIMUM_POSTS

        # Calculated using the Flesch Reading Ease formula,
        # with a statistical approximation for syllables (1.45 per word,
        # which is the average for English text). This is more reliable
        # than regex-based syllable counting which can be thrown off by
        # URLs, code blocks, and technical terminology.
        #
        # Tries to handle short sentences or ones without delimiters
        # and ending with emojis by treating them as a single sentence.
        #
        # Scores are bounded between 0-100 to prevent extreme negative values.
        readability_score = DB.query_single(<<~SQL).first
          WITH cleaned AS (
            #{posts.select("posts.word_count AS words", "regexp_replace(posts.cooked, '<[^>]+>', ' ', 'g') AS plain").to_sql}
          ),
          metrics AS (
            SELECT
              words,
              CASE
                WHEN regexp_count(plain, '[.!?;:](\s|$)') = 0 AND words > 5 THEN 1
                ELSE regexp_count(plain, '[.!?;:](\s|$)')
              END AS sentences
            FROM cleaned
          )
          SELECT AVG(GREATEST(0, LEAST(100, 206.835 - 1.015 * (words::float / sentences) - 84.6 * 1.45)))
          FROM metrics
          WHERE words > 0 AND sentences > 0
        SQL

        {
          data: {
            total_words:,
            total_posts:,
            average_post_length: (total_words.to_f / total_posts).round(2),
            readability_score:,
          },
          identifier: "writing-analysis",
        }
      end
    end
  end
end
