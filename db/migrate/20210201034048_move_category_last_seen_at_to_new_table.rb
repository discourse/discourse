# frozen_string_literal: true

class MoveCategoryLastSeenAtToNewTable < ActiveRecord::Migration[6.0]
  def up
    sql = <<~SQL
      INSERT INTO dismissed_topic_users (user_id, topic_id, created_at)
      SELECT users.id, topics.id, category_users.last_seen_at
      FROM category_users
      JOIN users ON users.id = category_users.user_id
      JOIN categories ON categories.id = category_users.category_id
      JOIN user_stats ON user_stats.user_id = users.id
      JOIN user_options ON user_options.user_id = users.id
      JOIN topics ON topics.category_id = category_users.category_id
      WHERE category_users.last_seen_at IS NOT NULL
      AND topics.created_at >= GREATEST(CASE
                  WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :always THEN users.created_at
                  WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(users.previous_visit_at,users.created_at)
                  ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(user_options.new_topic_duration_minutes, :default_duration))
               END, user_stats.new_since, :min_date)
      AND topics.created_at <= category_users.last_seen_at
      ORDER BY topics.created_at DESC
      LIMIT :max_new_topics
    SQL
    sql =
      DB.sql_fragment(
        sql,
        now: DateTime.now,
        last_visit: User::NewTopicDuration::LAST_VISIT,
        always: User::NewTopicDuration::ALWAYS,
        default_duration: SiteSetting.default_other_new_topic_duration_minutes,
        min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime,
        max_new_topics: SiteSetting.max_new_topics,
      )
    DB.exec(sql)
  end

  def down
    raise IrreversibleMigration
  end
end
