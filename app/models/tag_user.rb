# frozen_string_literal: true

class TagUser < ActiveRecord::Base
  belongs_to :tag
  belongs_to :user

  scope :notification_level_visible, -> (notification_levels = TagUser.notification_levels.values) {
    select("tag_users.*")
      .distinct
      .joins("LEFT OUTER JOIN tag_group_memberships ON tag_users.tag_id = tag_group_memberships.tag_id")
      .joins("LEFT OUTER JOIN tag_group_permissions ON tag_group_memberships.tag_group_id = tag_group_permissions.tag_group_id")
      .joins("LEFT OUTER JOIN group_users on group_users.user_id = tag_users.user_id")
      .where("(tag_group_permissions.group_id IS NULL
               OR tag_group_permissions.group_id IN (:everyone_group_id, group_users.group_id)
               OR group_users.group_id = :staff_group_id)
              AND tag_users.notification_level IN (:notification_levels)",
             staff_group_id: Group::AUTO_GROUPS[:staff],
             everyone_group_id: Group::AUTO_GROUPS[:everyone],
             notification_levels: notification_levels)
  }

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

    tag_ids = if tags.empty?
      []
    elsif tags.first&.is_a?(String)
      Tag.where_name(tags).pluck(:id)
    else
      tags
    end

    Tag.where(id: tag_ids).joins(:target_tag).each do |tag|
      tag_ids[tag_ids.index(tag.id)] = tag.target_tag_id
    end

    tag_ids.uniq!

    if tag_ids.present? &&
        TagUser.where(user_id: user.id, tag_id: tag_ids)
            .where
            .not(notification_level: notification_levels[level])
            .update_all(notification_level: notification_levels[level]) > 0

      changed = true
    end

    remove = (old_ids - tag_ids)
    if remove.present?
      records.where('tag_id in (?)', remove).destroy_all
      changed = true
    end

    now = Time.zone.now

    new_records_attrs = (tag_ids - old_ids).map do |tag_id|
      {
        user_id: user.id,
        tag_id: tag_id,
        notification_level: notification_levels[level],
        created_at: now,
        updated_at: now
      }
    end

    unless new_records_attrs.empty?
      result = TagUser.insert_all(new_records_attrs)
      changed = true if result.rows.length > 0
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

  def self.notification_levels_for(user)
    # Anonymous users have all default tags set to regular tracking,
    # except for default muted tags which stay muted.
    if user.blank?
      notification_levels = [
        SiteSetting.default_tags_watching_first_post.split("|"),
        SiteSetting.default_tags_watching.split("|"),
        SiteSetting.default_tags_tracking.split("|")
      ].flatten.map do |name|
        [name, self.notification_levels[:regular]]
      end

      notification_levels += SiteSetting.default_tags_muted.split("|").map do |name|
        [name, self.notification_levels[:muted]]
      end
    else
      notification_levels = TagUser
        .notification_level_visible
        .where(user: user)
        .joins(:tag).pluck("tags.name", :notification_level)
    end

    Hash[*notification_levels.flatten]
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
