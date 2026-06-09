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
      elsif report.facets.include?(:prev_period)
        counts = User.real.count_by_signup_date(report.prev_start_date, report.end_date)
        current_counts, previous_counts = split_date_counts(counts, report.start_date)

        report.data = current_counts.map { |date, count| { x: date, y: count } }
        report.prev_period = previous_counts.sum { |_date, count| count }

        report.total = User.real.count if report.facets.include?(:total)

        if report.facets.include?(:prev30Days)
          report.prev30Days =
            User
              .real
              .where(
                "users.created_at >= ? and users.created_at < ?",
                report.start_date - 30.days,
                report.start_date,
              )
              .count
        end
      else
        report_about report, User.real, :count_by_signup_date
      end
    end
  end
end
