# frozen_string_literal: true

class MoveNewSinceToNewTable < ActiveRecord::Migration[6.0]
  def up
    sql = <<~SQL
      INSERT INTO dismissed_topic_users (user_id, topic_id, created_at)
      SELECT users.id, topics.id, user_stats.new_since
      FROM user_stats
      JOIN users ON users.id = user_stats.user_id
      JOIN user_options ON user_options.user_id = users.id
      LEFT JOIN topics ON topics.created_at <= user_stats.new_since
      LEFT JOIN topic_users ON topics.id = topic_users.topic_id AND users.id = topic_users.user_id
      LEFT JOIN dismissed_topic_users ON dismissed_topic_users.topic_id = topics.id AND users.id = dismissed_topic_users.user_id
      WHERE user_stats.new_since IS NOT NULL
      AND topic_users.id IS NULL
      AND dismissed_topic_users.id IS NULL
      AND topics.archetype <> :private_message
      AND topics.created_at >= GREATEST(CASE
                  WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :always THEN users.created_at
                  WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(users.previous_visit_at,users.created_at)
                  ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(user_options.new_topic_duration_minutes, :default_duration))
               END, :min_date)
      ORDER BY topics.created_at DESC
      LIMIT :max_new_topics
    SQL
    DB.exec(sql,
            now: DateTime.now,
            last_visit: User::NewTopicDuration::LAST_VISIT,
            always: User::NewTopicDuration::ALWAYS,
            default_duration: SiteSetting.default_other_new_topic_duration_minutes,
            min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime,
            private_message: Archetype.private_message,
            max_new_topics: SiteSetting.max_new_topics)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
