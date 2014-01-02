class CategoryUser < ActiveRecord::Base
  belongs_to :category
  belongs_to :user

  # same for now
  def self.notification_levels
    TopicUser.notification_levels
  end

  def self.auto_watch_new_topic(topic)
    apply_default_to_topic(
                           topic,
                           TopicUser.notification_levels[:watching],
                           TopicUser.notification_reasons[:auto_watch_category]
                          )
  end

  def self.auto_mute_new_topic(topic)
    apply_default_to_topic(
                           topic,
                           TopicUser.notification_levels[:muted],
                           TopicUser.notification_reasons[:auto_mute_category]
                          )
  end

  private

  def self.apply_default_to_topic(topic, level, reason)
    # Can not afford to slow down creation of topics when a pile of users are watching new topics, reverting to SQL for max perf here
    sql = <<SQL
    INSERT INTO topic_users(user_id, topic_id, notification_level, notifications_reason_id)
    SELECT user_id, :topic_id, :level, :reason
    FROM category_users
    WHERE notification_level = :level AND
          category_id = :category_id AND
          NOT EXISTS(SELECT 1 FROM topic_users WHERE topic_id = :topic_id AND user_id = category_users.user_id)
SQL

    exec_sql(
        sql,
                  topic_id: topic.id,
                  category_id: topic.category_id,
                  level: level,
                  reason: reason

            )
  end

end
