# frozen_string_literal: true

class GroupUser < ActiveRecord::Base
  belongs_to :group
  belongs_to :user

  after_save :update_title
  after_destroy :grant_other_available_title

  after_save :set_primary_group
  after_destroy :remove_primary_and_flair_group, :recalculate_trust_level

  before_create :set_notification_level
  after_save :grant_trust_level
  after_save :set_category_notifications
  after_save :set_tag_notifications

  after_commit :increase_group_user_count, on: [:create]
  after_commit :decrease_group_user_count, on: [:destroy]

  def self.notification_levels
    NotificationLevels.all
  end

  def self.ensure_consistency!(last_seen = 1.hour.ago)
    update_first_unread_pm(last_seen)
  end

  def self.update_first_unread_pm(last_seen, limit: 10_000)
    whisperers_group_ids = SiteSetting.whispers_allowed_group_ids

    DB.exec(
      <<~SQL,
    UPDATE group_users gu
    SET first_unread_pm_at = Y.min_date
    FROM (
      SELECT
        X.group_id,
        X.user_id,
        X.min_date
      FROM (
        SELECT
          gu.group_id,
          gu.user_id,
          COALESCE(Z.min_date, :now) min_date
        FROM group_users gu
        LEFT JOIN (
          SELECT
            gu2.group_id,
            gu2.user_id,
            MIN(t.updated_at) min_date
          FROM group_users gu2
          INNER JOIN topic_allowed_groups tag ON tag.group_id = gu2.group_id
          INNER JOIN topics t ON t.id = tag.topic_id
          INNER JOIN users u ON u.id = gu2.user_id
          LEFT JOIN topic_users tu ON t.id = tu.topic_id AND tu.user_id = gu2.user_id
          WHERE t.deleted_at IS NULL
          AND t.archetype = :archetype
          AND tu.last_read_post_number < CASE
                                         WHEN u.admin OR u.moderator #{whisperers_group_ids.present? ? "OR gu2.group_id IN (:whisperers_group_ids)" : ""}
                                         THEN t.highest_staff_post_number
                                         ELSE t.highest_post_number
                                         END
          AND (COALESCE(tu.notification_level, 1) >= 2)
          GROUP BY gu2.user_id, gu2.group_id
        ) AS Z ON Z.user_id = gu.user_id AND Z.group_id = gu.group_id
      ) AS X
      WHERE X.user_id IN (
        SELECT id
        FROM users
        WHERE last_seen_at IS NOT NULL
        AND last_seen_at > :last_seen
        ORDER BY last_seen_at DESC
        LIMIT :limit
      )
    ) Y
    WHERE gu.user_id = Y.user_id AND gu.group_id = Y.group_id
    SQL
      archetype: Archetype.private_message,
      last_seen: last_seen,
      limit: limit,
      now: 10.minutes.ago,
      whisperers_group_ids: whisperers_group_ids,
    )
  end

  protected

  def set_notification_level
    self.notification_level = group&.default_notification_level || 3
  end

  def set_primary_group
    user.update!(primary_group: group) if group.primary_group
  end

  def remove_primary_and_flair_group
    return if self.destroyed_by_association&.active_record == User # User is being destroyed, so don't try to update

    updates = {}
    updates[:primary_group_id] = nil if user.primary_group_id == group_id
    updates[:flair_group_id] = nil if user.flair_group_id == group_id

    user.update(updates) if updates.present?
  end

  def grant_other_available_title
    if group.title.present? && group.title == user.title
      user.update_attribute(:title, user.next_best_title)
    end
  end

  def update_title
    if group.title.present?
      DB.exec(
        "
        UPDATE users SET title = :title
        WHERE (title IS NULL OR title = '') AND id = :id",
        id: user_id,
        title: group.title,
      )
    end
  end

  def grant_trust_level
    return if group.grant_trust_level.nil?

    TrustLevelGranter.grant(group.grant_trust_level, user)
  end

  def recalculate_trust_level
    return if group.grant_trust_level.nil?
    return if self.destroyed_by_association&.active_record == User # User is being destroyed, so don't try to recalculate

    Promotion.recalculate(user, use_previous_trust_level: true)
  end

  def set_category_notifications
    self.class.set_category_notifications(group, user)
  end

  def self.set_category_notifications(group, user)
    group_levels =
      group
        .group_category_notification_defaults
        .each_with_object({}) do |r, h|
          h[r.notification_level] ||= []
          h[r.notification_level] << r.category_id
        end

    return if group_levels.empty?

    user_levels =
      CategoryUser
        .where(user_id: user.id)
        .each_with_object({}) do |r, h|
          h[r.notification_level] ||= []
          h[r.notification_level] << r.category_id
        end

    higher_level_category_ids = user_levels.values.flatten

    %i[muted regular tracking watching_first_post watching].each do |level|
      level_num = NotificationLevels.all[level]
      higher_level_category_ids -= (user_levels[level_num] || [])
      if group_category_ids = group_levels[level_num]
        CategoryUser.batch_set(
          user,
          level,
          group_category_ids + (user_levels[level_num] || []) - higher_level_category_ids,
        )
      end
    end
  end

  def set_tag_notifications
    self.class.set_tag_notifications(group, user)
  end

  def self.set_tag_notifications(group, user)
    group_levels =
      group
        .group_tag_notification_defaults
        .each_with_object({}) do |r, h|
          h[r.notification_level] ||= []
          h[r.notification_level] << r.tag_id
        end

    return if group_levels.empty?

    user_levels =
      TagUser
        .where(user_id: user.id)
        .each_with_object({}) do |r, h|
          h[r.notification_level] ||= []
          h[r.notification_level] << r.tag_id
        end

    higher_level_tag_ids = user_levels.values.flatten

    %i[muted regular tracking watching_first_post watching].each do |level|
      level_num = NotificationLevels.all[level]
      higher_level_tag_ids -= (user_levels[level_num] || [])
      if group_tag_ids = group_levels[level_num]
        TagUser.batch_set(
          user,
          level,
          group_tag_ids + (user_levels[level_num] || []) - higher_level_tag_ids,
        )
      end
    end
  end

  def increase_group_user_count
    Group.increment_counter(:user_count, self.group_id)
  end

  def decrease_group_user_count
    Group.decrement_counter(:user_count, self.group_id)
  end
end

# == Schema Information
#
# Table name: group_users
#
#  id                 :integer          not null, primary key
#  group_id           :integer          not null
#  user_id            :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  owner              :boolean          default(FALSE), not null
#  notification_level :integer          default(2), not null
#  first_unread_pm_at :datetime         not null
#
# Indexes
#
#  index_group_users_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#  index_group_users_on_user_id_and_group_id  (user_id,group_id) UNIQUE
#
