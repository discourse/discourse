class CategoryUser < ActiveRecord::Base
  belongs_to :category
  belongs_to :user

  def self.lookup(user, level)
    self.where(user: user, notification_level: notification_levels[level])
  end

  def self.lookup_by_category(user, category)
    self.where(user: user, category: category)
  end

  # same for now
  def self.notification_levels
    TopicUser.notification_levels
  end

  def self.auto_track_new_topic(topic)
    apply_default_to_topic(
                           topic,
                           TopicUser.notification_levels[:tracking],
                           TopicUser.notification_reasons[:auto_track_category]
                          )
  end

  def self.auto_watch_new_topic(topic)
    apply_default_to_topic(
                           topic,
                           TopicUser.notification_levels[:watching],
                           TopicUser.notification_reasons[:auto_watch_category]
                          )
  end

  def self.batch_set(user, level, category_ids)
    records = CategoryUser.where(user: user, notification_level: notification_levels[level])
    old_ids = records.pluck(:category_id)

    category_ids = Category.where('id in (?)', category_ids).pluck(:id)

    remove = (old_ids - category_ids)
    if remove.present?
      records.where('category_id in (?)', remove).destroy_all
    end

    (category_ids - old_ids).each do |id|
      CategoryUser.create!(user: user, category_id: id, notification_level: notification_levels[level])
    end
  end

  def self.set_notification_level_for_category(user, level, category_id)
    record = CategoryUser.where(user: user, category_id: category_id).first
    # oder CategoryUser.where(user: user, category_id: category_id).destroy_all
    # und danach mir create anlegen.

    if record.present?
      record.notification_level = level
      record.save!
    else
      CategoryUser.create!(user: user, category_id: category_id, notification_level: level)
    end
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

# == Schema Information
#
# Table name: category_users
#
#  id                 :integer          not null, primary key
#  category_id        :integer          not null
#  user_id            :integer          not null
#  notification_level :integer          not null
#
