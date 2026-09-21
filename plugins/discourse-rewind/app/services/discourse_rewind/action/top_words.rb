# frozen_string_literal: true

module DiscourseRewind
  module Action
    class TopWords < BaseReport
      IGNORED_WORDS = %w[
        com
        org
        net
        io
        dev
        co
        uk
        http
        https
        www
        github
        gitlab
        google
        youtube
        twitter
        slack
        discord
        drive
      ].freeze
      SIMPLE_TS_CONFIG = "simple"
      WORD_PATTERN = "^[^[:digit:][:punct:][:space:]]{2,}$"
      WORD_COUNT = 5
      CANDIDATE_COUNT = 100
      LINKS_REGEX = "https?://[^\\s]+"
      RAW_TSVECTOR_SQL =
        "to_tsvector('#{SIMPLE_TS_CONFIG}', regexp_replace(raw, '#{LINKS_REGEX}', ' ', 'g'))"

      FakeData = {
        data: [
          { word: "seven", score: 100 },
          { word: "longest", score: 90 },
          { word: "you", score: 80 },
          { word: "overachieved", score: 70 },
          { word: "assume", score: 60 },
        ],
        identifier: "top-words",
      }

      def call
        return FakeData if should_use_fake_data?

        data = word_query.map { |row| { word: row.original_word, score: row.ndoc + row.nentry } }

        { data:, identifier: "top-words" }
      end

      private

      def word_query
        posts = self.class.publicly_visible_posts.where(user_id: user.id, created_at: date)
        stem = "strip(to_tsvector('#{Search.ts_config}', #{Search.wrap_unaccent("word")}))"

        DB.query(<<~SQL)
          WITH popular_words AS (
            SELECT
              word, ndoc, nentry
            FROM
              ts_stat($INNERSQL$
                #{posts.joins(:post_search_data).select(:search_data).to_sql}
              $INNERSQL$)
            WHERE
              word ~ '#{WORD_PATTERN}'
              AND word NOT IN (
                SELECT unnest(tsvector_to_array(strip(to_tsvector('#{Search.ts_config}', ignored))))
                FROM unnest(ARRAY[#{IGNORED_WORDS.map { |word| "'#{word}'" }.join(", ")}]) AS ignored
              )
            ORDER BY
              nentry DESC, ndoc DESC, word
            LIMIT #{CANDIDATE_COUNT}
          ), lex AS (
            SELECT DISTINCT ON (stem)
              #{stem} AS stem,
              word AS original_word
            FROM
              ts_stat($INNERSQL$
                #{posts.select(RAW_TSVECTOR_SQL).to_sql}
              $INNERSQL$)
            WHERE
              word ~ '#{WORD_PATTERN}'
            ORDER BY
              stem, nentry DESC, word
          )
          SELECT
            ndoc, nentry, original_word
          FROM
            popular_words
          INNER JOIN
            lex ON lex.stem = strip(to_tsvector('#{SIMPLE_TS_CONFIG}', popular_words.word))
          ORDER BY
            ndoc + nentry DESC, popular_words.word
          LIMIT #{WORD_COUNT}
        SQL
      end
    end
  end
end
