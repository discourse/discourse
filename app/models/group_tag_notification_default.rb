# frozen_string_literal: true

class GroupTagNotificationDefault < ActiveRecord::Base
  belongs_to :group
  belongs_to :tag

  def self.notification_levels
    NotificationLevels.all
  end

  def self.lookup(group, level)
    self.where(group: group, notification_level: notification_levels[level])
  end

  def self.batch_set(group, level, tag_names)
    tag_names ||= []
    changed = false

    records = self.where(group: group, notification_level: notification_levels[level])
    old_ids = records.pluck(:tag_id)

    tag_ids = tag_names.empty? ? [] : Tag.where_name(tag_names).pluck(:id)

    Tag
      .where_name(tag_names)
      .joins(:target_tag)
      .each { |tag| tag_ids[tag_ids.index(tag.id)] = tag.target_tag_id }

    tag_ids.uniq!

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
#  group_id           :integer          not null
#  tag_id             :integer          not null
#  notification_level :integer          not null
#
# Indexes
#
#  idx_group_tag_notification_defaults_unique  (group_id,tag_id) UNIQUE
#
