# frozen_string_literal: true

class ExcludeSmallActionPostsFromTopicStats < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 2_000

  def up
    bounds = DB.query_single(<<~SQL)
        SELECT COALESCE(MIN(id), 0), COALESCE(MAX(id), 0)
        FROM topics
        WHERE archetype <> 'private_message'
      SQL

    min_id, max_id = bounds[0].to_i, bounds[1].to_i
    return if max_id.zero?

    (min_id..max_id).step(BATCH_SIZE) { |low| recalculate_batch(low, low + BATCH_SIZE - 1) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def recalculate_batch(low, high)
    DB.exec(<<~SQL, low: low, high: high)
      WITH stats AS (
        SELECT topic_id,
               COALESCE(MAX(post_number), 0) AS highest_post_number,
               COUNT(*) AS posts_count,
               MAX(created_at) AS last_posted_at,
               SUM(COALESCE(word_count, 0)) AS word_count,
               (array_agg(user_id ORDER BY created_at DESC))[1] AS last_post_user_id
        FROM posts
        WHERE deleted_at IS NULL
          AND topic_id BETWEEN :low AND :high
          AND post_type <> 4
          AND NOT (post_type = 3 AND ((raw IS NULL OR TRIM(raw) = '') OR version <= 1))
        GROUP BY topic_id
      )
      UPDATE topics
      SET
        highest_post_number = stats.highest_post_number,
        posts_count = stats.posts_count,
        last_posted_at = stats.last_posted_at,
        word_count = stats.word_count,
        last_post_user_id = COALESCE(stats.last_post_user_id, topics.last_post_user_id)
      FROM stats
      WHERE stats.topic_id = topics.id
        AND topics.id BETWEEN :low AND :high
        AND topics.archetype <> 'private_message'
        AND (
          topics.highest_post_number <> stats.highest_post_number OR
          topics.posts_count <> stats.posts_count
        )
    SQL

    DB.exec(<<~SQL, low: low, high: high)
      UPDATE topic_users
      SET last_read_post_number = topics.highest_post_number
      FROM topics
      WHERE topic_users.topic_id = topics.id
        AND topics.id BETWEEN :low AND :high
        AND topic_users.last_read_post_number > topics.highest_post_number
        AND topics.archetype <> 'private_message'
    SQL
  end
end
