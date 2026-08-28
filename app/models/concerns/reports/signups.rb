# frozen_string_literal: true

module Reports::Signups
  extend ActiveSupport::Concern

  class_methods do
    def report_signups(report)
      report.icon = "user-plus"

      group_filter = report.filters.dig(:group)
      report.add_filter("group", type: "group", default: group_filter)

      if group_filter
        basic_report_about report,
                           User.real,
                           :count_by_signup_date,
                           report.start_date,
                           report.end_date,
                           group_filter
        add_counts report, User.real, "users.created_at"
      else
        report_about report, User.real, :count_by_signup_date
      end

      return if report.guardian.blank?

      users = User.real.where(created_at: report.start_date..report.end_date)
      users =
        users.joins(:group_users).where(group_users: { group_id: group_filter }) if group_filter
      users = users.order(created_at: :desc)

      report.related_items_totals = { users: users.count }
      users = users.limit(report.limit || Report::RELATED_ITEMS_LIMIT)

      report.related_items = {
        users:
          users.map do |user|
            {
              user: BasicUserSerializer.new(user, scope: report.guardian, root: false).as_json,
              timestamp: user.created_at.iso8601,
            }
          end,
      }
    end
  end
end
