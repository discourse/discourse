# frozen_string_literal: true

class GroupCategoryNotificationDefault < ActiveRecord::Base
  belongs_to :group
  belongs_to :category

  def self.notification_levels
    NotificationLevels.all
  end

  def self.lookup(group, level)
    self.where(group: group, notification_level: notification_levels[level])
  end

  def self.batch_set(group, level, category_ids)
    level_num = notification_levels[level]
    category_ids = Category.where(id: category_ids).pluck(:id)

    changed = false

    # Update pre-existing
    if category_ids.present? &&
         GroupCategoryNotificationDefault
           .where(group_id: group.id, category_id: category_ids)
           .where.not(notification_level: level_num)
           .update_all(notification_level: level_num) > 0
      changed = true
    end

    # Remove extraneous category users
    if GroupCategoryNotificationDefault
         .where(group_id: group.id, notification_level: level_num)
         .where.not(category_id: category_ids)
         .delete_all > 0
      changed = true
    end

    if category_ids.present?
      params = { group_id: group.id, level_num: level_num }

      sql = <<~SQL
        INSERT INTO group_category_notification_defaults (group_id, category_id, notification_level)
        SELECT :group_id, :category_id, :level_num
        ON CONFLICT DO NOTHING
      SQL

      # we could use VALUES here but it would introduce a string
      # into the query, plus it is a bit of a micro optimisation
      category_ids.each do |category_id|
        params[:category_id] = category_id
        changed = true if DB.exec(sql, params) > 0
      end
    end

    changed
  end
end

# == Schema Information
#
# Table name: group_category_notification_defaults
#
#  id                 :bigint           not null, primary key
#  group_id           :integer          not null
#  category_id        :integer          not null
#  notification_level :integer          not null
#
# Indexes
#
#  idx_group_category_notification_defaults_unique  (group_id,category_id) UNIQUE
#
