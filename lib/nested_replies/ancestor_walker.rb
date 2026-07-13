# frozen_string_literal: true

module NestedReplies
  # Walks the reply_to_post_number chain from `start_post_number` toward root
  # in a single recursive CTE. Returns an array of result objects, each with
  # .id, .post_number, .reply_to_post_number, and .depth (1 = start post).
  def self.walk_ancestors(
    topic_id:,
    start_post_number:,
    limit: nil,
    exclude_deleted: true,
    stop_at_op: false
  )
    deleted_seed = exclude_deleted ? "AND deleted_at IS NULL" : ""
    deleted_recurse = exclude_deleted ? "AND p.deleted_at IS NULL" : ""
    op_stop = stop_at_op ? "AND a.reply_to_post_number != 1" : ""
    depth_limit = limit.present? ? "AND a.depth < :limit" : ""

    DB.query(<<~SQL, topic_id: topic_id, start: start_post_number, limit: limit)
      WITH RECURSIVE ancestors AS (
        SELECT id,
               post_number,
               reply_to_post_number,
               deleted_at,
               1 AS depth,
               ARRAY[post_number]::integer[] AS path
        FROM posts
        WHERE topic_id = :topic_id
          AND post_number = :start
          #{deleted_seed}
        UNION ALL
        SELECT p.id,
               p.post_number,
               p.reply_to_post_number,
               p.deleted_at,
               a.depth + 1,
               a.path || p.post_number
        FROM posts p
        JOIN ancestors a ON p.post_number = a.reply_to_post_number
        WHERE p.topic_id = :topic_id
          #{deleted_recurse}
          AND a.reply_to_post_number IS NOT NULL
          #{op_stop}
          #{depth_limit}
          AND NOT p.post_number = ANY(a.path)
      )
      SELECT id, post_number, reply_to_post_number, depth, deleted_at FROM ancestors
    SQL
  end
end
