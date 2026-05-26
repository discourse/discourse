# frozen_string_literal: true

class RecalculateTopicCountersWithoutSmallActions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    last_post_id = 0
    whisper_group_ids =
      DB.query_single(<<~SQL).first.to_s.split("|").map(&:to_i).select(&:positive?)
      SELECT value
      FROM site_settings
      WHERE name = 'whispers_allowed_groups'
    SQL

    loop do
      rows = DB.query(<<~SQL, last_post_id:, batch_size: BATCH_SIZE)
        SELECT id, topic_id
        FROM posts
        WHERE id > :last_post_id AND post_type = 3
        ORDER BY id
        LIMIT :batch_size
      SQL

      break if rows.empty?

      topic_ids = rows.map(&:topic_id).uniq

      DB.exec(<<~SQL, topic_ids:)
        WITH stats AS (
          SELECT
            posts.topic_id,
            COALESCE(
              MAX(posts.post_number) FILTER (
                WHERE posts.deleted_at IS NULL AND posts.post_type <> 3
              ),
              0
            ) AS highest_staff_post_number,
            COALESCE(
              MAX(posts.post_number) FILTER (
                WHERE posts.deleted_at IS NULL AND posts.post_type NOT IN (3, 4)
              ),
              0
            ) AS highest_post_number,
            COUNT(*) FILTER (
              WHERE posts.deleted_at IS NULL AND posts.post_type NOT IN (3, 4)
            ) AS posts_count,
            COALESCE(
              SUM(COALESCE(posts.word_count, 0)) FILTER (
                WHERE posts.deleted_at IS NULL AND posts.post_type NOT IN (3, 4)
              ),
              0
            ) AS word_count,
            MAX(posts.created_at) FILTER (
              WHERE posts.deleted_at IS NULL AND posts.post_type NOT IN (3, 4)
            ) AS last_posted_at
          FROM posts
          WHERE posts.topic_id IN (:topic_ids)
          GROUP BY posts.topic_id
        ), last_posts AS (
          SELECT DISTINCT ON (posts.topic_id)
            posts.topic_id,
            posts.user_id
          FROM posts
          WHERE posts.topic_id IN (:topic_ids) AND
            posts.deleted_at IS NULL AND
            posts.post_type NOT IN (3, 4)
          ORDER BY posts.topic_id, posts.created_at DESC, posts.id DESC
        )
        UPDATE topics
        SET highest_staff_post_number = stats.highest_staff_post_number,
            highest_post_number = stats.highest_post_number,
            posts_count = stats.posts_count,
            word_count = stats.word_count,
            last_posted_at = stats.last_posted_at,
            last_post_user_id = COALESCE(last_posts.user_id, topics.last_post_user_id)
        FROM stats
        LEFT JOIN last_posts ON last_posts.topic_id = stats.topic_id
        WHERE topics.id = stats.topic_id AND (
          topics.highest_staff_post_number <> stats.highest_staff_post_number OR
          topics.highest_post_number <> stats.highest_post_number OR
          topics.posts_count <> stats.posts_count OR
          topics.word_count <> stats.word_count OR
          topics.last_posted_at IS DISTINCT FROM stats.last_posted_at OR
          topics.last_post_user_id IS DISTINCT FROM COALESCE(last_posts.user_id, topics.last_post_user_id)
        )
      SQL

      if whisper_group_ids.empty?
        DB.exec(<<~SQL, topic_ids:)
          WITH stats AS (
            SELECT
              posts.topic_id,
              COALESCE(
                MAX(posts.post_number) FILTER (
                  WHERE posts.deleted_at IS NULL AND posts.post_type NOT IN (3, 4)
                ),
                0
              ) AS highest_post_number
            FROM posts
            WHERE posts.topic_id IN (:topic_ids)
            GROUP BY posts.topic_id
          )
          UPDATE topic_users
          SET last_read_post_number = stats.highest_post_number
          FROM stats
          WHERE topic_users.topic_id = stats.topic_id AND
            topic_users.last_read_post_number > stats.highest_post_number
        SQL
      else
        DB.exec(<<~SQL, topic_ids:, whisper_group_ids:)
          WITH stats AS (
            SELECT
              posts.topic_id,
              COALESCE(
                MAX(posts.post_number) FILTER (
                  WHERE posts.deleted_at IS NULL AND posts.post_type <> 3
                ),
                0
              ) AS highest_staff_post_number,
              COALESCE(
                MAX(posts.post_number) FILTER (
                  WHERE posts.deleted_at IS NULL AND posts.post_type NOT IN (3, 4)
                ),
                0
              ) AS highest_post_number
            FROM posts
            WHERE posts.topic_id IN (:topic_ids)
            GROUP BY posts.topic_id
          )
          UPDATE topic_users
          SET last_read_post_number = CASE
            WHEN EXISTS (
              SELECT 1
              FROM users
              WHERE users.id = topic_users.user_id AND (
                users.admin OR
                users.primary_group_id IN (:whisper_group_ids) OR
                EXISTS (
                  SELECT 1
                  FROM group_users
                  WHERE group_users.user_id = users.id AND
                    group_users.group_id IN (:whisper_group_ids)
                )
              )
            ) THEN stats.highest_staff_post_number
            ELSE stats.highest_post_number
          END
          FROM stats
          WHERE topic_users.topic_id = stats.topic_id AND
            topic_users.last_read_post_number > CASE
              WHEN EXISTS (
                SELECT 1
                FROM users
                WHERE users.id = topic_users.user_id AND (
                  users.admin OR
                  users.primary_group_id IN (:whisper_group_ids) OR
                  EXISTS (
                    SELECT 1
                    FROM group_users
                    WHERE group_users.user_id = users.id AND
                      group_users.group_id IN (:whisper_group_ids)
                  )
                )
              ) THEN stats.highest_staff_post_number
              ELSE stats.highest_post_number
            END
        SQL
      end

      last_post_id = rows.last.id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
