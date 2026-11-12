# frozen_string_literal: true

class RecalculateTopicCountersWithoutSmallActions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    whisper_group_ids =
      DB
        .query_single("SELECT value FROM site_settings WHERE name = 'whispers_allowed_groups'")
        .first
        .to_s
        .split("|")
        .map(&:to_i)
        .select(&:positive?)

    last_post_id = 0

    loop do
      rows = DB.query(<<~SQL, last_post_id:, batch_size: BATCH_SIZE)
        SELECT id, topic_id
        FROM posts
        WHERE post_type = 3 AND id > :last_post_id
        ORDER BY id
        LIMIT :batch_size
      SQL

      break if rows.empty?

      last_post_id = rows.last.id
      topic_ids = rows.map(&:topic_id).uniq

      recalculate_counters(topic_ids)
      clamp_last_read(topic_ids, whisper_group_ids)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def recalculate_counters(topic_ids)
    DB.exec(<<~SQL, topic_ids:)
      WITH stats AS (
        SELECT
          topic_id,
          COALESCE(MAX(post_number) FILTER (WHERE deleted_at IS NULL AND post_type <> 3), 0)
            AS highest_staff_post_number,
          COALESCE(MAX(post_number) FILTER (WHERE deleted_at IS NULL AND post_type NOT IN (3, 4)), 0)
            AS highest_post_number,
          COUNT(*) FILTER (WHERE deleted_at IS NULL AND post_type NOT IN (3, 4))
            AS posts_count,
          COALESCE(SUM(COALESCE(word_count, 0)) FILTER (WHERE deleted_at IS NULL AND post_type NOT IN (3, 4)), 0)
            AS word_count,
          MAX(created_at) FILTER (WHERE deleted_at IS NULL AND post_type NOT IN (3, 4))
            AS last_posted_at
        FROM posts
        WHERE topic_id IN (:topic_ids)
        GROUP BY topic_id
      ), last_posts AS (
        SELECT DISTINCT ON (topic_id) topic_id, user_id
        FROM posts
        WHERE topic_id IN (:topic_ids) AND deleted_at IS NULL AND post_type NOT IN (3, 4)
        ORDER BY topic_id, created_at DESC, id DESC
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
        topics.highest_staff_post_number IS DISTINCT FROM stats.highest_staff_post_number OR
        topics.highest_post_number IS DISTINCT FROM stats.highest_post_number OR
        topics.posts_count IS DISTINCT FROM stats.posts_count OR
        topics.word_count IS DISTINCT FROM stats.word_count OR
        topics.last_posted_at IS DISTINCT FROM stats.last_posted_at OR
        topics.last_post_user_id IS DISTINCT FROM COALESCE(last_posts.user_id, topics.last_post_user_id)
      )
    SQL
  end

  def clamp_last_read(topic_ids, whisper_group_ids)
    cap =
      "CASE WHEN #{whisperer_sql(whisper_group_ids)} THEN t.highest_staff_post_number ELSE t.highest_post_number END"

    binds = { topic_ids: }
    binds[:whisper_group_ids] = whisper_group_ids if whisper_group_ids.present?

    DB.exec(<<~SQL, **binds)
      UPDATE topic_users tu
      SET last_read_post_number = #{cap}
      FROM topics t
      WHERE tu.topic_id = t.id
        AND t.id IN (:topic_ids)
        AND tu.last_read_post_number > #{cap}
    SQL
  end

  def whisperer_sql(whisper_group_ids)
    group_check =
      if whisper_group_ids.present?
        <<~SQL
          OR EXISTS (
            SELECT 1 FROM group_users gu
            WHERE gu.user_id = u.id AND gu.group_id IN (:whisper_group_ids)
          )
        SQL
      else
        ""
      end

    <<~SQL
      EXISTS (
        SELECT 1 FROM users u
        WHERE u.id = tu.user_id AND (u.admin OR u.moderator #{group_check})
      )
    SQL
  end
end
