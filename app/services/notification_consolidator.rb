# frozen_string_literal: true

class NotificationConsolidator
  attr_reader :notification, :notification_type, :consolidation_type, :data

  def initialize(notification)
    @notification = notification
    @notification_type = notification.notification_type
    @data = notification.data_hash

    if notification_type == Notification.types[:liked]
      @consolidation_type = Notification.types[:liked_consolidated]
      @data[:username] = @data[:display_username]
    elsif notification_type == Notification.types[:private_message]
      post_id = @data[:original_post_id]
      return if post_id.blank?

      custom_field = PostCustomField.select(:value).find_by(post_id: post_id, name: "requested_group_id")
      return if custom_field.blank?

      group_id = custom_field.value.to_i
      group_name = Group.select(:name).find_by(id: group_id)&.name
      return if group_name.blank?

      @consolidation_type = Notification.types[:membership_request_consolidated]
      @data[:group_name] = group_name
    end
  end

  def consolidate!
    return if SiteSetting.notification_consolidation_threshold.zero? || consolidation_type.blank?

    update_consolidated_notification! || create_consolidated_notification!
  end

  def update_consolidated_notification!
    consolidated_notification = user_notifications.filter_by_consolidation_data(consolidation_type, data).first
    return if consolidated_notification.blank?

    data_hash = consolidated_notification.data_hash
    data_hash["count"] += 1

    Notification.transaction do
      consolidated_notification.update!(
          data: data_hash.to_json,
          read: false,
          updated_at: timestamp
      )
      notification.destroy!
    end

    consolidated_notification
  end

  def create_consolidated_notification!
    notifications = user_notifications.unread.filter_by_consolidation_data(notification_type, data)
    return if notifications.count <= SiteSetting.notification_consolidation_threshold

    consolidated_notification = nil

    Notification.transaction do
      timestamp = notifications.last.created_at
      data[:count] = notifications.count

      consolidated_notification = Notification.create!(
        notification_type: consolidation_type,
        user_id: notification.user_id,
        data: data.to_json,
        updated_at: timestamp,
        created_at: timestamp
      )

      notifications.destroy_all
    end

    consolidated_notification
  end

  private

  def user_notifications
    notification.user.notifications
  end

  def timestamp
    @timestamp ||= Time.zone.now
  end
end
