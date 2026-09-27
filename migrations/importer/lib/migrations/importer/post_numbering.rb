# frozen_string_literal: true

module Migrations
  module Importer
    # Gives every source post the `post_number` it gets in the destination, in
    # one pass over the IntermediateDB, before the first post is copied. A quote
    # may name a post that the copy only reaches much later, so the numbers have
    # to be known up front.
    #
    # A positive source number is kept when no other post in the same topic uses
    # it and it is above the destination topic's existing post numbers. Missing,
    # non-positive, duplicate, and already occupied numbers are replaced with
    # distinct numbers above that topic's highest existing or kept number, oldest
    # post first. Keeping usable source numbers preserves source permalink
    # coordinates without colliding when posts are added to an existing topic.
    class PostNumbering
      TOPIC_BATCH_SIZE = 1_000
      private_constant :TOPIC_BATCH_SIZE

      CREATE_EXISTING_NUMBERS_SQL = <<~SQL
        CREATE TEMP TABLE IF NOT EXISTS existing_topic_post_numbers (
          topic_original_id INTEGER PRIMARY KEY,
          highest_post_number INTEGER NOT NULL
        )
      SQL
      private_constant :CREATE_EXISTING_NUMBERS_SQL

      # `OR IGNORE` keeps the numbers assigned by an earlier run, including when
      # posts already copied by that run have raised the destination maximum.
      ASSIGN_SQL = <<~SQL
        WITH source_posts AS (
          SELECT original_id,
                 topic_id,
                 created_at,
                 post_number,
                 COUNT(*) OVER (PARTITION BY topic_id, post_number) AS source_number_count
          FROM posts
        ),
        mapped_highest AS (
          SELECT topic_original_id,
                 MAX(post_number) AS highest_post_number
          FROM mapped.post_numbers
          GROUP BY topic_original_id
        ),
        numbered AS (
          SELECT source_posts.original_id,
                 source_posts.topic_id,
                 source_posts.created_at,
                 MAX(
                   COALESCE(existing.highest_post_number, 0),
                   COALESCE(mapped_highest.highest_post_number, 0)
                 ) AS reserved_number,
                 CASE
                   WHEN source_posts.post_number >
                          MAX(
                            COALESCE(existing.highest_post_number, 0),
                            COALESCE(mapped_highest.highest_post_number, 0)
                          )
                        AND source_posts.source_number_count = 1
                     THEN source_posts.post_number
                 END AS kept_number
          FROM source_posts
               LEFT JOIN existing_topic_post_numbers existing
                 ON existing.topic_original_id = source_posts.topic_id
               LEFT JOIN mapped_highest
                 ON mapped_highest.topic_original_id = source_posts.topic_id
               LEFT JOIN mapped.post_numbers assigned
                 ON assigned.original_id = source_posts.original_id
          WHERE assigned.original_id IS NULL
        ),
        highest AS (
          SELECT topic_id,
                 MAX(reserved_number) AS reserved_number,
                 COALESCE(MAX(kept_number), 0) AS kept_number
          FROM numbered
          GROUP BY topic_id
        )
        INSERT OR IGNORE INTO mapped.post_numbers (original_id, topic_original_id, post_number)
        SELECT numbered.original_id,
               numbered.topic_id,
               COALESCE(
                 numbered.kept_number,
                 MAX(highest.reserved_number, highest.kept_number) +
                   ROW_NUMBER() OVER (
                     PARTITION BY numbered.topic_id, numbered.kept_number IS NULL
                     ORDER BY numbered.created_at, numbered.original_id
                   )
               )
        FROM numbered
             JOIN highest ON highest.topic_id = numbered.topic_id
      SQL
      private_constant :ASSIGN_SQL

      def initialize(intermediate_db, discourse_db)
        @intermediate_db = intermediate_db
        @discourse_db = discourse_db
      end

      def assign
        store_existing_topic_post_numbers
        @intermediate_db.execute(ASSIGN_SQL)

        nil
      end

      private

      def store_existing_topic_post_numbers
        @intermediate_db.execute(CREATE_EXISTING_NUMBERS_SQL)
        @intermediate_db.execute("DELETE FROM existing_topic_post_numbers")

        topic_mappings = @intermediate_db.query(<<~SQL, MappingType::TOPICS)
              SELECT DISTINCT mapped_topic.original_id, mapped_topic.discourse_id
              FROM mapped.ids mapped_topic
                   JOIN posts ON posts.topic_id = mapped_topic.original_id
              WHERE mapped_topic.type = ?
            SQL
        original_ids_by_discourse_id = topic_mappings.group_by { |row| row[:discourse_id] }

        original_ids_by_discourse_id
          .keys
          .each_slice(TOPIC_BATCH_SIZE) do |discourse_ids|
            placeholders = discourse_ids.each_index.map { |index| "$#{index + 1}" }.join(", ")
            rows = @discourse_db.query_array(<<~SQL, *discourse_ids)
              SELECT topic_id, MAX(post_number)
              FROM posts
              WHERE topic_id IN (#{placeholders})
              GROUP BY topic_id
            SQL

            rows.each do |discourse_id, highest_post_number|
              original_ids_by_discourse_id[discourse_id].each do |mapping|
                @intermediate_db.insert(<<~SQL, [mapping[:original_id], highest_post_number])
                  INSERT INTO existing_topic_post_numbers
                         (topic_original_id, highest_post_number)
                  VALUES (?, ?)
                SQL
              end
            end
          end
      end
    end
  end
end
