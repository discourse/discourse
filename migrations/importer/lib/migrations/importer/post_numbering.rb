# frozen_string_literal: true

module Migrations
  module Importer
    # Gives every source post the `post_number` it gets in the destination, in
    # one pass over the IntermediateDB, before the first post is copied. A quote
    # may name a post that the copy only reaches much later, so the numbers have
    # to be known up front.
    #
    # Posts are ordered by their source number and ID, then assigned contiguous
    # numbers. Topics that explicitly name an existing destination topic continue
    # after its highest post number; new topics start at one. Missing source
    # numbers sort last.
    class PostNumbering
      TOPIC_BATCH_SIZE = 1_000
      private_constant :TOPIC_BATCH_SIZE

      # `OR IGNORE` keeps the numbers assigned by an earlier run. New source rows
      # are appended after both those assignments and destination posts.
      ASSIGN_SQL = <<~SQL
        WITH mapped_highest AS (
          SELECT topic_original_id,
                 MAX(post_number) AS highest_post_number
          FROM mapped.post_numbers
          GROUP BY topic_original_id
        ),
        numbered AS (
          SELECT posts.original_id,
                 posts.topic_id,
                 MAX(
                   COALESCE(existing.highest_post_number, 0),
                   COALESCE(mapped_highest.highest_post_number, 0)
                 ) AS reserved_number,
                 ROW_NUMBER() OVER (
                   PARTITION BY posts.topic_id
                   ORDER BY posts.post_number IS NULL,
                            posts.post_number,
                            posts.original_id
                 ) AS sequence_number
          FROM posts
               LEFT JOIN existing_topic_post_numbers existing
                 ON existing.topic_original_id = posts.topic_id
               LEFT JOIN mapped_highest
                 ON mapped_highest.topic_original_id = posts.topic_id
               LEFT JOIN mapped.post_numbers assigned
                 ON assigned.original_id = posts.original_id
          WHERE assigned.original_id IS NULL
        )
        INSERT OR IGNORE INTO mapped.post_numbers (original_id, topic_original_id, post_number)
        SELECT numbered.original_id,
               numbered.topic_id,
               numbered.reserved_number + numbered.sequence_number
        FROM numbered
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
        @intermediate_db.execute(<<~SQL)
          CREATE TEMP TABLE IF NOT EXISTS existing_topic_post_numbers (
            topic_original_id INTEGER PRIMARY KEY,
            highest_post_number INTEGER NOT NULL
          )
        SQL
        @intermediate_db.execute("DELETE FROM existing_topic_post_numbers")

        topic_mappings = @intermediate_db.query(<<~SQL, MappingType::TOPICS)
              SELECT DISTINCT topics.original_id, mapped_topic.discourse_id
              FROM topics
                   JOIN mapped.ids mapped_topic
                     ON mapped_topic.original_id = topics.original_id
                        AND mapped_topic.type = ?
                   JOIN posts ON posts.topic_id = topics.original_id
              WHERE topics.existing_id IS NOT NULL
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
