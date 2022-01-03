# frozen_string_literal: true

module Notifications
  class ConsolidationPlanner
    def consolidate_or_save!(notification)
      plan = plan_for(notification)
      return :no_plan if plan.nil?

      plan.consolidate_or_save!(notification)
    end

    private

    def plan_for(notification)
      consolidation_plans = [liked_by_two_users, liked, group_message_summary, group_membership]
      consolidation_plans.concat(DiscoursePluginRegistry.notification_consolidation_plans)

      consolidation_plans.detect { |plan| plan.can_consolidate_data?(notification) }
    end

    def liked
      ConsolidateNotifications.new(
        from: Notification.types[:liked],
        to: Notification.types[:liked_consolidated],
        threshold: -> { SiteSetting.notification_consolidation_threshold },
        consolidation_window: SiteSetting.likes_notification_consolidation_window_mins.minutes,
        unconsolidated_query_blk: Proc.new do |notifications, data|
          key = 'display_username'
          value = data[key.to_sym]
          filtered = notifications.where("data::json ->> 'username2' IS NULL")

          filtered = filtered.where("data::json ->> '#{key}' = ?", value) if value

          filtered
        end,
        consolidated_query_blk: filtered_by_data_attribute('display_username')
      ).set_mutations(
        set_data_blk: Proc.new do |notification|
          data = notification.data_hash
          data.merge(username: data[:display_username])
        end
      ).set_precondition(precondition_blk: Proc.new { |data| data[:username2].blank? })
    end

    def liked_by_two_users
      DeletePreviousNotifications.new(
        type: Notification.types[:liked],
        previous_query_blk: Proc.new do |notifications, data|
          notifications.where(id: data[:previous_notification_id])
        end
      ).set_mutations(
        set_data_blk: Proc.new do |notification|
          existing_notification_of_same_type = Notification
            .where(user: notification.user)
            .order("notifications.id DESC")
            .where(topic_id: notification.topic_id, post_number: notification.post_number)
            .where(notification_type: notification.notification_type)
            .where('created_at > ?', 1.day.ago)
            .first

          data = notification.data_hash
          if existing_notification_of_same_type
            same_type_data = existing_notification_of_same_type.data_hash
            data.merge(
              previous_notification_id: existing_notification_of_same_type.id,
              username2: same_type_data[:display_username],
              count: (same_type_data[:count] || 1).to_i + 1
            )
          else
            data
          end
        end
      ).set_precondition(
        precondition_blk: Proc.new do |data, notification|
          always_freq = UserOption.like_notification_frequency_type[:always]

          notification.user&.user_option&.like_notification_frequency == always_freq &&
            data[:previous_notification_id].present?
        end
      )
    end

    def group_membership
      ConsolidateNotifications.new(
        from: Notification.types[:private_message],
        to: Notification.types[:membership_request_consolidated],
        threshold: -> { SiteSetting.notification_consolidation_threshold },
        consolidation_window: Notification::MEMBERSHIP_REQUEST_CONSOLIDATION_WINDOW_HOURS.hours,
        unconsolidated_query_blk: filtered_by_data_attribute('topic_title'),
        consolidated_query_blk: filtered_by_data_attribute('group_name')
      ).set_precondition(
        precondition_blk: Proc.new { |data| data[:group_name].present? }
      ).set_mutations(
        set_data_blk: Proc.new do |notification|
          data = notification.data_hash
          post_id = data[:original_post_id]
          custom_field = PostCustomField.select(:value).find_by(post_id: post_id, name: "requested_group_id")
          group_id = custom_field&.value
          group_name = group_id.present? ? Group.select(:name).find_by(id: group_id.to_i)&.name : nil

          data[:group_name] = group_name
          data
        end
      )
    end

    def group_message_summary
      DeletePreviousNotifications.new(
        type: Notification.types[:group_message_summary],
        previous_query_blk: filtered_by_data_attribute('group_id')
      ).set_precondition(
        precondition_blk: Proc.new { |data| data[:group_id].present? }
      )
    end

    def filtered_by_data_attribute(attribute_name)
      Proc.new do |notifications, data|
        if (value = data[attribute_name.to_sym])
          notifications.where("data::json ->> '#{attribute_name}' = ?", value.to_s)
        else
          notifications
        end
      end
    end
  end
end
