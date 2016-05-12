class TagUser < ActiveRecord::Base
  belongs_to :tag
  belongs_to :user

  def self.notification_levels
    TopicUser.notification_levels
  end

  %w{watch track}.each do |s|
    define_singleton_method("auto_#{s}_new_topic") do |topic, new_tags=nil|
      tag_ids = topic.tags.pluck(:id)
      if !new_tags.nil? && topic.created_at && topic.created_at > 5.days.ago
        tag_ids = new_tags.map(&:id)
        remove_default_from_topic( topic.id, tag_ids,
                                   TopicUser.notification_levels[:"#{s}ing"],
                                   TopicUser.notification_reasons[:"auto_#{s}_tag"] )
      end

      apply_default_to_topic( topic.id, tag_ids,
                              TopicUser.notification_levels[:"#{s}ing"],
                              TopicUser.notification_reasons[:"auto_#{s}_tag"])
    end
  end

  def self.apply_default_to_topic(topic_id, tag_ids, level, reason)
    sql = <<-SQL
      INSERT INTO topic_users(user_id, topic_id, notification_level, notifications_reason_id)
           SELECT user_id, :topic_id, :level, :reason
             FROM tag_users
            WHERE notification_level = :level
              AND tag_id in (:tag_ids)
              AND NOT EXISTS(SELECT 1 FROM topic_users WHERE topic_id = :topic_id AND user_id = tag_users.user_id)
            LIMIT 1
    SQL

    exec_sql(sql,
      topic_id: topic_id,
      tag_ids: tag_ids,
      level: level,
      reason: reason
    )
  end

  def self.remove_default_from_topic(topic_id, tag_ids, level, reason)
    sql = <<-SQL
      DELETE FROM topic_users
            WHERE topic_id = :topic_id
              AND notifications_changed_at IS NULL
              AND notification_level = :level
              AND notifications_reason_id = :reason
    SQL

    if !tag_ids.empty?
      sql << <<-SQL
                AND NOT EXISTS(
                  SELECT 1
                    FROM tag_users
                   WHERE tag_users.tag_id in (:tag_ids)
                     AND tag_users.notification_level = :level
                     AND tag_users.user_id = topic_users.user_id)
      SQL
    end

    exec_sql(sql,
      topic_id: topic_id,
      level: level,
      reason: reason,
      tag_ids: tag_ids
    )
  end

  private_class_method :apply_default_to_topic
end
