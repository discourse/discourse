# frozen_string_literal: true

class MoveNewSinceToNewTableAgain < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!
  BATCH_SIZE = 30_000

  def up
    offset = 0
    loop do
      min_id, max_id = DB.query_single(<<~SQL, offset: offset, batch_size: BATCH_SIZE)
        SELECT min(user_id), max(user_id)
        FROM (
          SELECT user_id
          FROM user_stats
          ORDER BY user_id
          LIMIT :batch_size
          OFFSET :offset
        ) X
      SQL

      # will return nil
      break if !min_id

      sql = <<~SQL
        INSERT INTO dismissed_topic_users (user_id, topic_id, created_at)
        SELECT users.id, topics.id, user_stats.new_since
        FROM user_stats
        JOIN users ON users.id = user_stats.user_id
        JOIN user_options ON user_options.user_id = users.id
        LEFT JOIN topics ON topics.created_at <= user_stats.new_since
          AND topics.archetype <> :private_message
          AND topics.created_at >= GREATEST(CASE
                      WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :always THEN users.created_at
                      WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(users.previous_visit_at,users.created_at)
                      ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(user_options.new_topic_duration_minutes, :default_duration))
                   END, :min_date)
          AND topics.id IN(SELECT id FROM topics ORDER BY created_at DESC LIMIT :max_new_topics)
        LEFT JOIN topic_users ON topics.id = topic_users.topic_id AND users.id = topic_users.user_id
        LEFT JOIN dismissed_topic_users ON dismissed_topic_users.topic_id = topics.id AND users.id = dismissed_topic_users.user_id
        WHERE user_stats.new_since IS NOT NULL
        AND user_stats.user_id >= :min_id
        AND user_stats.user_id <= :max_id
        AND topic_users.last_read_post_number IS NULL
        AND topics.id IS NOT NULL
        AND dismissed_topic_users.id IS NULL
        ORDER BY topics.created_at DESC
        ON CONFLICT DO NOTHING
      SQL

      DB.exec(
        sql,
        now: DateTime.now,
        last_visit: User::NewTopicDuration::LAST_VISIT,
        always: User::NewTopicDuration::ALWAYS,
        default_duration: SiteSetting.default_other_new_topic_duration_minutes,
        min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime,
        private_message: Archetype.private_message,
        min_id: min_id,
        max_id: max_id,
        max_new_topics: SiteSetting.max_new_topics,
      )

      offset += BATCH_SIZE
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
