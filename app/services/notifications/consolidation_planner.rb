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

      consolidation_plans.detect { |plan| plan.can_consolidate_data?(notification) }
    end

    def notification_consolidation_plans
      [liked, group_membership, group_message_summary]
    end

    def liked
      ConsolidateNotifications.new(
        from: Notification.types[:liked],
        to: Notification.types[:liked_consolidated],
        set_data_blk: ->(data) { data.merge(username: data[:display_username]) },
        precondition_blk: ->(_) { true },
        threshold: SiteSetting.notification_consolidation_threshold
      )
    end

    def group_membership
      ConsolidateNotifications.new(
        from: Notification.types[:private_message],
        to: Notification.types[:membership_request_consolidated],
        set_data_blk: ->(data) do
          post_id = data[:original_post_id]
          custom_field = PostCustomField.select(:value).find_by(post_id: post_id, name: "requested_group_id")
          group_id = custom_field&.value
          group_name = group_id.present? ? Group.select(:name).find_by(id: group_id.to_i)&.name : nil

          data[:group_name] = group_name
          data
        end,
        precondition_blk: ->(data) { data[:group_name].present? },
        threshold: SiteSetting.notification_consolidation_threshold
      )
    end

    def group_message_summary
      ConsolidateNotifications.new(
        from: Notification.types[:group_message_summary],
        to: Notification.types[:group_message_summary],
        set_data_blk: ->(data) { data },
        precondition_blk: ->(_) { true },
        threshold: 1 # We should always apply this plan to refresh the summary stats
      )
    end

    def dashboard_problems_pm
      ConsolidateNotifications.new(
        from: Notification.types[:private_message],
        to: Notification.types[:private_message],
        set_data_blk: ->(data) { data },
        precondition_blk: ->(data) do
          data[:topic_title] == I18n.t("system_messages.dashboard_problems.subject_template")
        end,
        threshold: 1
      )
    end
  end
end
