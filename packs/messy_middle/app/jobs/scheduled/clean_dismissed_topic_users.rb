# frozen_string_literal: true

module Jobs
  class CleanDismissedTopicUsers < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      delete_overdue_dismissals!
      delete_over_the_limit_dismissals!
    end

    private

    def delete_overdue_dismissals!
      sql = <<~SQL
        DELETE FROM dismissed_topic_users dtu1
        USING dismissed_topic_users dtu2
        JOIN topics ON topics.id = dtu2.topic_id
        JOIN users ON users.id = dtu2.user_id
        JOIN categories ON categories.id = topics.category_id
        LEFT JOIN user_stats ON user_stats.user_id = users.id
        LEFT JOIN user_options ON user_options.user_id = users.id
        WHERE topics.created_at < GREATEST(CASE
                    WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :always THEN users.created_at
                    WHEN COALESCE(user_options.new_topic_duration_minutes, :default_duration) = :last_visit THEN COALESCE(users.previous_visit_at,users.created_at)
                    ELSE (:now::timestamp - INTERVAL '1 MINUTE' * COALESCE(user_options.new_topic_duration_minutes, :default_duration))
                 END, users.created_at, :min_date)
        AND dtu1.id = dtu2.id
      SQL
      sql =
        DB.sql_fragment(
          sql,
          now: DateTime.now,
          last_visit: User::NewTopicDuration::LAST_VISIT,
          always: User::NewTopicDuration::ALWAYS,
          default_duration: SiteSetting.default_other_new_topic_duration_minutes,
          min_date: Time.at(SiteSetting.min_new_topics_time).to_datetime,
        )
      DB.exec(sql)
    end

    def delete_over_the_limit_dismissals!
      user_ids = DismissedTopicUser.distinct(:user_id).pluck(:user_id)
      sql = <<~SQL
      DELETE FROM dismissed_topic_users
      WHERE dismissed_topic_users.id NOT IN (
        SELECT valid_dtu.id FROM users
        LEFT JOIN dismissed_topic_users valid_dtu ON valid_dtu.user_id = users.id
        AND valid_dtu.topic_id IN (
          SELECT topic_id FROM dismissed_topic_users dtu2
          JOIN topics ON topics.id = dtu2.topic_id
          WHERE dtu2.user_id = users.id
          ORDER BY topics.created_at DESC
          LIMIT :max_new_topics
        )
        WHERE users.id IN(:user_ids)
      )
      SQL
      sql = DB.sql_fragment(sql, max_new_topics: SiteSetting.max_new_topics, user_ids: user_ids)
      DB.exec(sql)
    end
  end
end
