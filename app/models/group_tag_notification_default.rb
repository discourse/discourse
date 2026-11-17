# frozen_string_literal: true

class GroupTagNotificationDefault < ActiveRecord::Base
  belongs_to :group
  belongs_to :tag

  def self.notification_levels
    NotificationLevels.all
  end

  def self.lookup(group, level)
    where(group: group, notification_level: notification_levels[level])
  end

  def self.resolve_tag_ids(tag_names)
    return [] if tag_names.blank?

    Tag
      .where_name(tag_names)
      .pluck(:id, :target_tag_id)
      .map { |id, target_id| target_id || id }
      .uniq
  end

  def self.batch_set(group, level, tag_names)
    tag_names ||= []
    changed = false

    records = where(group: group, notification_level: notification_levels[level])
    old_ids = records.pluck(:tag_id)

    tag_ids = resolve_tag_ids(tag_names)

    if where(group:, tag_id: tag_ids)
         .where.not(notification_level: notification_levels[level])
         .update_all(notification_level: notification_levels[level]) > 0
      changed = true
    end

    remove = (old_ids - tag_ids)
    if remove.present?
      records.where("tag_id in (?)", remove).destroy_all
      changed = true
    end

    new_records_attrs =
      (tag_ids - old_ids).map do |tag_id|
        { group_id: group.id, tag_id: tag_id, notification_level: notification_levels[level] }
      end

    unless new_records_attrs.empty?
      result = GroupTagNotificationDefault.insert_all(new_records_attrs)
      changed = true if result.rows.length > 0
    end

    changed
  end
end

# == Schema Information
#
# Table name: group_tag_notification_defaults
#
#  id                 :bigint           not null, primary key
#  notification_level :integer          not null
#  group_id           :integer          not null
#  tag_id             :integer          not null
#
# Indexes
#
#  idx_group_tag_notification_defaults_unique  (group_id,tag_id) UNIQUE
#
