# frozen_string_literal: true

class GroupUser < ActiveRecord::Base
  belongs_to :group, counter_cache: "user_count"
  belongs_to :user

  after_save :update_title
  after_destroy :grant_other_available_title

  after_save :set_primary_group
  after_destroy :remove_primary_group, :recalculate_trust_level

  before_create :set_notification_level
  after_save :grant_trust_level
  after_save :set_category_notifications
  after_save :set_tag_notifications

  def self.notification_levels
    NotificationLevels.all
  end

  protected

  def set_notification_level
    self.notification_level = group&.default_notification_level || 3
  end

  def set_primary_group
    user.update!(primary_group: group) if group.primary_group
  end

  def remove_primary_group
    DB.exec("
      UPDATE users
      SET primary_group_id = NULL
      WHERE id = :user_id AND primary_group_id = :id",
      id: group.id, user_id: user_id
    )
  end

  def grant_other_available_title
    if group.title.present? && group.title == user.title
      user.update_attribute(:title, user.next_best_title)
    end
  end

  def update_title
    if group.title.present?
      DB.exec("
        UPDATE users SET title = :title
        WHERE (title IS NULL OR title = '') AND id = :id",
        id: user_id, title: group.title
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

    Promotion.recalculate(user)
  end

  def set_category_notifications
    self.class.set_category_notifications(group, user)
  end

  def self.set_category_notifications(group, user)
    group_levels = group.group_category_notification_defaults.each_with_object({}) do |r, h|
      h[r.notification_level] ||= []
      h[r.notification_level] << r.category_id
    end

    return if group_levels.empty?

    user_levels = CategoryUser.where(user_id: user.id).each_with_object({}) do |r, h|
      h[r.notification_level] ||= []
      h[r.notification_level] << r.category_id
    end

    higher_level_category_ids = user_levels.values.flatten

    [:muted, :regular, :tracking, :watching_first_post, :watching].each do |level|
      level_num = NotificationLevels.all[level]
      higher_level_category_ids -= (user_levels[level_num] || [])
      if group_category_ids = group_levels[level_num]
        CategoryUser.batch_set(
          user,
          level,
          group_category_ids + (user_levels[level_num] || []) - higher_level_category_ids
        )
      end
    end
  end

  def set_tag_notifications
    self.class.set_tag_notifications(group, user)
  end

  def self.set_tag_notifications(group, user)
    group_levels = group.group_tag_notification_defaults.each_with_object({}) do |r, h|
      h[r.notification_level] ||= []
      h[r.notification_level] << r.tag_id
    end

    return if group_levels.empty?

    user_levels = TagUser.where(user_id: user.id).each_with_object({}) do |r, h|
      h[r.notification_level] ||= []
      h[r.notification_level] << r.tag_id
    end

    higher_level_tag_ids = user_levels.values.flatten

    [:muted, :regular, :tracking, :watching_first_post, :watching].each do |level|
      level_num = NotificationLevels.all[level]
      higher_level_tag_ids -= (user_levels[level_num] || [])
      if group_tag_ids = group_levels[level_num]
        TagUser.batch_set(
          user,
          level,
          group_tag_ids + (user_levels[level_num] || []) - higher_level_tag_ids
        )
      end
    end
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
#
# Indexes
#
#  index_group_users_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#  index_group_users_on_user_id_and_group_id  (user_id,group_id) UNIQUE
#
