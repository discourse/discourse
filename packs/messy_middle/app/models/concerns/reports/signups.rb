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
    end
  end
end
