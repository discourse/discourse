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
      consolidation_plans = [liked, dashboard_problems_pm, group_message_summary, group_membership]
      consolidation_plans.concat(DiscoursePluginRegistry.notification_consolidation_plans)

      consolidation_plans.detect { |plan| plan.can_consolidate_data?(notification) }
    end

    def liked
      ConsolidateNotifications.new(
        from: Notification.types[:liked],
        to: Notification.types[:liked_consolidated],
        threshold: -> { SiteSetting.notification_consolidation_threshold },
        consolidation_window: SiteSetting.likes_notification_consolidation_window_mins.minutes,
        unconsolidated_query_blk: ->(notifications, data) do
          key = 'display_username'
          value = data[key.to_sym]
          filtered = notifications.where("data::json ->> 'username2' IS NULL")

          filtered = filtered.where("data::json ->> '#{key}' = ?", value) if value

          filtered
        end,
        consolidated_query_blk: filtered_by_data_attribute('display_username')
      ).set_mutations(
        set_data_blk: ->(notification) do
          data = notification.data_hash
          data.merge(username: data[:display_username])
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
        precondition_blk: ->(data) { data[:group_name].present? }
      ).set_mutations(
        set_data_blk: ->(notification) do
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
      ConsolidateNotifications.new(
        from: Notification.types[:group_message_summary],
        to: Notification.types[:group_message_summary],
        unconsolidated_query_blk: filtered_by_data_attribute('group_id'),
        consolidated_query_blk: filtered_by_data_attribute('group_id'),
        threshold: 1 # We should always apply this plan to refresh the summary stats
      ).set_precondition(
        precondition_blk: ->(data) { data[:group_id].present? }
      )
    end

    def dashboard_problems_pm
      ConsolidateNotifications.new(
        from: Notification.types[:private_message],
        to: Notification.types[:private_message],
        threshold: 1,
        unconsolidated_query_blk: filtered_by_data_attribute('topic_title'),
        consolidated_query_blk: filtered_by_data_attribute('topic_title')
      ).set_precondition(
        precondition_blk: ->(data) do
          data[:topic_title] == I18n.t("system_messages.dashboard_problems.subject_template")
        end
      )
    end

    def filtered_by_data_attribute(attribute_name)
      ->(notifications, data) do
        if (value = data[attribute_name.to_sym])
          notifications.where("data::json ->> '#{attribute_name}' = ?", value.to_s)
        else
          notifications
        end
      end
    end
  end
end
