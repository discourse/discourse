class TagUser < ActiveRecord::Base
  belongs_to :tag
  belongs_to :user

  def self.notification_levels
    TopicUser.notification_levels
  end

  def self.change(user_id, tag_id, level)
    tag_id = tag_id.id if tag_id.is_a?(::Tag)
    user_id = user_id.id if user_id.is_a?(::User)

    tag_id = tag_id.to_i
    user_id = user_id.to_i

    tag_user = TagUser.where(user_id: user_id, tag_id: tag_id).first

    if tag_user
      return tag_user if tag_user.notification_level == level
      tag_user.notification_level = level
      tag_user.save
    else
      tag_user = TagUser.create(user_id: user_id, tag_id: tag_id, notification_level: level)
    end

    tag_user
  rescue ActiveRecord::RecordNotUnique
    # In case of a race condition to insert, do nothing
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

  private_class_method :apply_default_to_topic, :remove_default_from_topic
end

# == Schema Information
#
# Table name: tag_users
#
#  id                 :integer          not null, primary key
#  tag_id             :integer          not null
#  user_id            :integer          not null
#  notification_level :integer          not null
#  created_at         :datetime
#  updated_at         :datetime
#
# Indexes
#
#  idx_tag_users_ix1  (user_id,tag_id,notification_level) UNIQUE
#  idx_tag_users_ix2  (tag_id,user_id,notification_level) UNIQUE
#
