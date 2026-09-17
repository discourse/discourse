# frozen_string_literal: true

module Migrations
  module Importer
    # Gives every source post the `post_number` it gets in the destination, in
    # one pass over the IntermediateDB, before the first post is copied. A quote
    # may name a post that the copy only reaches much later, so the numbers have
    # to be known up front.
    #
    # A source number is kept when it is usable as it is: greater than zero and
    # used by only one post of its topic. Every other post is numbered after the
    # topic's highest kept number, oldest post first. That keeps the numbers a
    # source already had - they show up in its permalinks - and still leaves each
    # topic with unique numbers.
    class PostNumbering
      # The numbers only depend on the source rows, so a second run of the same
      # import computes the same values again. `OR IGNORE` keeps the numbers an
      # earlier run already copied into the destination.
      ASSIGN_SQL = <<~SQL
        WITH numbered AS (
          SELECT original_id,
                 topic_id,
                 created_at,
                 CASE
                   WHEN post_number > 0
                        AND COUNT(*) OVER (PARTITION BY topic_id, post_number) = 1
                     THEN post_number
                 END AS kept_number
          FROM posts
        ),
        highest AS (
          SELECT topic_id,
                 COALESCE(MAX(kept_number), 0) AS kept_number
          FROM numbered
          GROUP BY topic_id
        )
        INSERT OR IGNORE INTO mapped.post_numbers (original_id, topic_original_id, post_number)
        SELECT numbered.original_id,
               numbered.topic_id,
               COALESCE(
                 numbered.kept_number,
                 highest.kept_number +
                   ROW_NUMBER() OVER (
                     PARTITION BY numbered.topic_id, numbered.kept_number IS NULL
                     ORDER BY numbered.created_at, numbered.original_id
                   )
               )
        FROM numbered
             JOIN highest ON highest.topic_id = numbered.topic_id
      SQL
      private_constant :ASSIGN_SQL

      def initialize(intermediate_db)
        @intermediate_db = intermediate_db
      end

      def assign
        @intermediate_db.execute(ASSIGN_SQL)

        nil
      end
    end
  end
end
