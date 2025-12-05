# frozen_string_literal: true

module DiscourseRewind
  module Action
    class TopWords < BaseReport
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
        return FakeData if Rails.env.development?

        words = DB.query(<<~SQL, user_id: user.id, date_start: date.first, date_end: date.last)
        WITH popular_words AS (
          SELECT
            *
          FROM
            ts_stat(
              $INNERSQL$
                SELECT
                  search_data
                FROM
                  post_search_data
                INNER JOIN
                  posts ON posts.id = post_search_data.post_id
                WHERE
                  posts.user_id = :user_id
                  AND posts.created_at BETWEEN :date_start AND :date_end
              $INNERSQL$
            ) AS search_data
          WHERE LENGTH(word) >= 2
          AND word ~ '^[a-zA-Z]+$'
          AND word NOT IN (
             'com', 'org', 'net', 'io', 'dev', 'co', 'uk', 'http', 'https',
             'www', 'github', 'gitlab', 'google', 'youtube', 'twitter',
             'slack', 'discord', 'drive'
           )
          ORDER BY
            nentry DESC,
            ndoc DESC,
            word
          LIMIT
            100
        ), lex AS (
          SELECT
            DISTINCT ON (lexeme) to_tsvector('english', word) as lexeme,
            word as original_word
          FROM
            ts_stat ($INNERSQL$
              SELECT
                to_tsvector('simple',
                  regexp_replace(raw, 'https?://[^\\s]+', ' ', 'g')
                )
              FROM
                posts AS p
              WHERE
                p.user_id = :user_id
                AND p.created_at BETWEEN :date_start AND :date_end
            $INNERSQL$)
          WHERE LENGTH(word) >= 2
          AND word ~ '^[a-zA-Z]+$'
        ), ranked_words AS (
          SELECT
            popular_words.*, lex.original_word,
            ROW_NUMBER() OVER (PARTITION BY word ORDER BY LENGTH(original_word) DESC) AS rn
          FROM
            popular_words
          INNER JOIN
            lex ON lex.lexeme @@ to_tsquery('english', popular_words.word)
        )
        SELECT
          word,
          ndoc,
          nentry,
          original_word
        FROM
          ranked_words
        WHERE
          rn = 1
        ORDER BY
          ndoc + nentry DESC
        LIMIT 10
      SQL

        word_score =
          words
            .map do |word_data|
              # Little cheat, since sometimes the stemming process turns
              # "discourse" into "discour" or "discours"
              if word_data.original_word == "discour" || word_data.original_word == "discours"
                word_data.original_word = "discourse"
              end

              { word: word_data.original_word, score: word_data.ndoc + word_data.nentry }
            end
            .sort_by! { |w| -w[:score] }
            .take(5)

        { data: word_score, identifier: "top-words" }
      end
    end
  end
end
