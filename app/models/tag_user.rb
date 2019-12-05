# frozen_string_literal: true

class TagUser < ActiveRecord::Base
  belongs_to :tag
  belongs_to :user

  def self.notification_levels
    NotificationLevels.all
  end

  def self.lookup(user, level)
    where(user: user, notification_level: notification_levels[level])
  end

  def self.batch_set(user, level, tags)
    tags ||= []
    changed = false

    records = TagUser.where(user: user, notification_level: notification_levels[level])
    old_ids = records.pluck(:tag_id)

    tag_ids = tags.empty? ? [] : Tag.where_name(tags).pluck(:id)

    Tag.where_name(tags).joins(:target_tag).each do |tag|
      tag_ids[tag_ids.index(tag.id)] = tag.target_tag_id
    end

    tag_ids.uniq!

    remove = (old_ids - tag_ids)
    if remove.present?
      records.where('tag_id in (?)', remove).destroy_all
      changed = true
    end

    (tag_ids - old_ids).each do |id|
      TagUser.create!(user: user, tag_id: id, notification_level: notification_levels[level])
      changed = true
    end

    if changed
      auto_watch(user_id: user.id)
      auto_track(user_id: user.id)
    end

    changed
  end

  def self.change(user_id, tag_id, level)
    if tag_id.is_a?(::Tag)
      tag = tag_id
      tag_id = tag.id
    else
      tag = Tag.find_by_id(tag_id)
    end

    if tag.synonym?
      tag_id = tag.target_tag_id
    end

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

    auto_watch(user_id: user_id)
    auto_track(user_id: user_id)

    tag_user
  rescue ActiveRecord::RecordNotUnique
    # In case of a race condition to insert, do nothing
  end

  def self.auto_watch(opts)
    builder = DB.build <<~SQL
      UPDATE topic_users
      SET notification_level = CASE WHEN should_watch THEN :watching ELSE :tracking END,
          notifications_reason_id = CASE WHEN should_watch THEN :auto_watch_tag ELSE NULL END
      FROM
      (
      SELECT tu.topic_id, tu.user_id, CASE
          WHEN MAX(tag_users.notification_level) = :watching THEN true
          ELSE false
          END
        should_watch,

          CASE WHEN MAX(tag_users.notification_level) IS NULL AND
            tu.notification_level = :watching AND
            tu.notifications_reason_id = :auto_watch_tag
          THEN true
          ELSE false
          END
        should_track

      FROM topic_users tu
      LEFT JOIN topic_tags ON tu.topic_id = topic_tags.topic_id
      LEFT JOIN tag_users ON tag_users.user_id = tu.user_id
                          AND topic_tags.tag_id = tag_users.tag_id
                          AND tag_users.notification_level = :watching
      /*where*/
      GROUP BY tu.topic_id, tu.user_id, tu.notification_level, tu.notifications_reason_id
      ) AS X
      WHERE X.topic_id = topic_users.topic_id AND
            X.user_id = topic_users.user_id AND
            (should_track OR should_watch)

    SQL

    builder.where("tu.notification_level in (:tracking, :regular, :watching)")

    if topic_id = opts[:topic_id]
      builder.where("tu.topic_id = :topic_id", topic_id: topic_id)
    end

    if user_id = opts[:user_id]
      builder.where("tu.user_id = :user_id", user_id: user_id)
    end

    builder.exec(watching: notification_levels[:watching],
                 tracking: notification_levels[:tracking],
                 regular: notification_levels[:regular],
                 auto_watch_tag: TopicUser.notification_reasons[:auto_watch_tag])

  end

  def self.auto_track(opts)
    builder = DB.build <<~SQL
      UPDATE topic_users
      SET notification_level = :tracking, notifications_reason_id = :auto_track_tag
      FROM (
          SELECT DISTINCT tu.topic_id, tu.user_id
          FROM topic_users tu
          JOIN topic_tags ON tu.topic_id = topic_tags.topic_id
          JOIN tag_users ON tag_users.user_id = tu.user_id
                              AND topic_tags.tag_id = tag_users.tag_id
                              AND tag_users.notification_level = :tracking
          /*where*/
      ) as X
      WHERE
        topic_users.notification_level = :regular AND
        topic_users.topic_id = X.topic_id AND
        topic_users.user_id = X.user_id
    SQL

    if topic_id = opts[:topic_id]
      builder.where("tu.topic_id = :topic_id", topic_id: topic_id)
    end

    if user_id = opts[:user_id]
      builder.where("tu.user_id = :user_id", user_id: user_id)
    end

    builder.exec(tracking: notification_levels[:tracking],
                 regular: notification_levels[:regular],
                 auto_track_tag: TopicUser.notification_reasons[:auto_track_tag])
  end

end

# == Schema Information
#
# Table name: tag_users
#
#  id                 :integer          not null, primary key
#  tag_id             :integer          not null
#  user_id            :integer          not null
#  notification_level :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  idx_tag_users_ix1  (user_id,tag_id,notification_level) UNIQUE
#  idx_tag_users_ix2  (tag_id,user_id,notification_level) UNIQUE
#
