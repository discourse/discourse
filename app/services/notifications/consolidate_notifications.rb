# frozen_string_literal: true

# Represents a rule to consolidate a specific notification.
#
# If a consolidated notification already exists, we'll update it instead.
# If it doesn't and creating a new one would match the threshold, we delete existing ones and create a consolidated one.
# Otherwise, save the original one.
#
# Constructor arguments:
#
# - from: The notification type of the unconsolidated notification. e.g. `Notification.types[:private_message]`
# - to: The type the consolidated notification will have. You can use the same value as from to flatten notifications or bump existing ones.
# - set_data_blk: A block that receives the notification data hash and mutates it, adding additional data needed for consolidation.
# - precondition_blk: A block that receives the mutated data and returns true if we have everything we need to consolidate.
# - threshold: If creating a new notification would match this number, we'll destroy existing ones and create a consolidated one.

module Notifications
  class ConsolidateNotifications
    def initialize(from:, to:, set_data_blk:, precondition_blk:, threshold:)
      @from = from
      @to = to
      @set_data_blk = set_data_blk
      @precondition_blk = precondition_blk
      @threshold = threshold
    end

    def can_consolidate_data?(notification)
      return false if threshold.zero? || to.blank?
      return false if notification.notification_type != from

      @data = consolidated_data(notification)
      @precondition_blk.call(data)
    end

    def consolidate_or_save!(notification)
      @data ||= consolidated_data(notification)
      return unless can_consolidate_data?(notification)

      update_consolidated_notification!(notification) ||
      create_consolidated_notification!(notification) ||
      notification.tap(&:save!)
    end

    private

    attr_reader :notification, :from, :to, :data, :threshold

    def consolidated_data(notification)
      @set_data_blk.call(notification.data_hash)
    end

    def update_consolidated_notification!(notification)
      consolidated = user_notifications(notification).filter_by_consolidation_data(to, data).first
      return if consolidated.blank?

      data_hash = consolidated.data_hash.merge(data)
      data_hash[:count] += 1  if data_hash[:count].present?

      # Hack: We don't want to cache the old data if we're about to update it.
      consolidated.instance_variable_set(:@data_hash, nil)

      consolidated.update!(
        data: data_hash.to_json,
        read: false,
        updated_at: timestamp
      )

      consolidated
    end

    def create_consolidated_notification!(notification)
      notifications = user_notifications(notification).unread.filter_by_consolidation_data(from, data)

      # Saving the new notification would pass the threshold? Consolidate instead.
      count_after_saving_notification = notifications.count + 1
      return if count_after_saving_notification <= threshold

      timestamp = notifications.last.created_at
      data[:count] = count_after_saving_notification

      consolidated = nil

      Notification.transaction do
        consolidated = Notification.create!(
          notification_type: to,
          user_id: notification.user_id,
          data: data.to_json,
          updated_at: timestamp,
          created_at: timestamp
        )

        notifications.destroy_all
      end

      consolidated
    end

    def user_notifications(notification)
      notification.user.notifications
    end

    def timestamp
      @timestamp ||= Time.zone.now
    end
  end
end
