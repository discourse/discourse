# frozen_string_literal: true

# Create a new notification while deleting previous versions of it.
#
# Constructor arguments:
#
# - type: The notification type. e.g. `Notification.types[:private_message]`
# - previous_query_blk: A block with the query we'll use to find previous notifications.
#
# Need to call #set_precondition to configure this:
#
# - precondition_blk: A block that receives the mutated data and returns true if we have everything we need to consolidate.
#
# Need to call #set_mutations to configure this:
#
# - set_data_blk: A block that receives the notification data hash and mutates it, adding additional data needed for consolidation.

module Notifications
  class DeletePreviousNotifications < ConsolidationPlan
    def initialize(type:, previous_query_blk:)
      @type = type
      @previous_query_blk = previous_query_blk
    end

    def can_consolidate_data?(notification)
      return false if notification.notification_type != type

      @data = consolidated_data(notification)

      precondition_blk.nil? || precondition_blk.call(@data, notification)
    end

    def consolidate_or_save!(notification)
      @data ||= consolidated_data(notification)
      return unless can_consolidate_data?(notification)

      notifications = user_notifications(notification, type)
      if previous_query_blk.present?
        notifications = previous_query_blk.call(notifications, data)
      end

      notification.data = data.to_json

      Notification.transaction do
        notifications.destroy_all
        notification.save!
      end

      notification
    end

    private

    attr_reader :type, :data, :precondition_blk, :previous_query_blk
  end
end
