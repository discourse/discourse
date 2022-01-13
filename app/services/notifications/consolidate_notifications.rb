# frozen_string_literal: true

# Consolidate notifications based on a threshold and a time window.
#
# If a consolidated notification already exists, we'll update it instead.
# If it doesn't and creating a new one would match the threshold, we delete existing ones and create a consolidated one.
# Otherwise, save the original one.
#
# Constructor arguments:
#
# - from: The notification type of the unconsolidated notification. e.g. `Notification.types[:private_message]`
# - to: The type the consolidated notification will have. You can use the same value as from to flatten notifications or bump existing ones.
# - threshold: If creating a new notification would match this number, we'll destroy existing ones and create a consolidated one. It also accepts a lambda that returns a number.
# - consolidation_window: Only consolidate notifications created since this value (Pass a ActiveSupport::Duration instance, and we'll call #ago on it).
# - unconsolidated_query_blk: A block with additional queries to apply when fetching for unconsolidated notifications.
# - consolidated_query_blk: A block with additional queries to apply when fetching for a consolidated notification.
#
# Need to call #set_precondition to configure this:
#
# - precondition_blk: A block that receives the mutated data and returns true if we have everything we need to consolidate.
#
# Need to call #set_mutations to configure this:
#
# - set_data_blk: A block that receives the notification data hash and mutates it, adding additional data needed for consolidation.
#
# Need to call #before_consolidation_callbacks to configure this:
#
# - before_update_blk: A block that is called before updating an already consolidated notification.
#                      Receives the consolidated object, the data hash, and the original notification.
#
# - before_consolidation_blk: A block that is called before creating a consolidated object.
#                             Receives an ActiveRecord::Relation with notifications about to be consolidated, and the new data hash.
#

module Notifications
  class ConsolidateNotifications < ConsolidationPlan
    def initialize(from:, to:, consolidation_window: nil, unconsolidated_query_blk: nil, consolidated_query_blk: nil, threshold:)
      @from = from
      @to = to
      @threshold = threshold
      @consolidation_window = consolidation_window
      @consolidated_query_blk = consolidated_query_blk
      @unconsolidated_query_blk = unconsolidated_query_blk
      @precondition_blk = nil
      @set_data_blk = nil
      @bump_notification = bump_notification
    end

    def before_consolidation_callbacks(before_update_blk: nil, before_consolidation_blk: nil)
      @before_update_blk = before_update_blk
      @before_consolidation_blk = before_consolidation_blk
      self
    end

    def can_consolidate_data?(notification)
      return false if get_threshold.zero? || to.blank?
      return false if notification.notification_type != from

      @data = consolidated_data(notification)

      return true if @precondition_blk.nil?
      @precondition_blk.call(data, notification)
    end

    def consolidate_or_save!(notification)
      @data ||= consolidated_data(notification)
      return unless can_consolidate_data?(notification)

      update_consolidated_notification!(notification) ||
      create_consolidated_notification!(notification) ||
      notification.tap(&:save!)
    end

    private

    attr_reader(
      :notification, :from, :to, :data, :threshold, :consolidated_query_blk,
      :unconsolidated_query_blk, :consolidation_window, :bump_notification
    )

    def update_consolidated_notification!(notification)
      notifications = user_notifications(notification, to)

      if consolidated_query_blk.present?
        notifications = consolidated_query_blk.call(notifications, data)
      end
      consolidated = notifications.first
      return if consolidated.blank?

      data_hash = consolidated.data_hash.merge(data)
      data_hash[:count] += 1 if data_hash[:count].present?

      if @before_update_blk
        @before_update_blk.call(consolidated, data_hash, notification)
      end

      # Hack: We don't want to cache the old data if we're about to update it.
      consolidated.instance_variable_set(:@data_hash, nil)

      consolidated.update!(
        data: data_hash.to_json,
        read: false,
        updated_at: timestamp,
      )

      consolidated
    end

    def create_consolidated_notification!(notification)
      notifications = user_notifications(notification, from)
      if unconsolidated_query_blk.present?
        notifications = unconsolidated_query_blk.call(notifications, data)
      end

      # Saving the new notification would pass the threshold? Consolidate instead.
      count_after_saving_notification = notifications.count + 1
      return if count_after_saving_notification <= get_threshold

      timestamp = notifications.last.created_at
      data[:count] = count_after_saving_notification

      if @before_consolidation_blk
        @before_consolidation_blk.call(notifications, data)
      end

      consolidated = nil

      Notification.transaction do
        notifications.destroy_all

        consolidated = Notification.create!(
          notification_type: to,
          user_id: notification.user_id,
          data: data.to_json,
          updated_at: timestamp,
          created_at: timestamp
        )
      end

      consolidated
    end

    def get_threshold
      threshold.is_a?(Proc) ? threshold.call : threshold
    end

    def user_notifications(notification, type)
      notifications = super(notification, type)

      if consolidation_window.present?
        notifications = notifications.where('created_at > ?', consolidation_window.ago)
      end

      notifications
    end

    def timestamp
      @timestamp ||= Time.zone.now
    end
  end
end
