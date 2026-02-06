# frozen_string_literal: true

module Reports::Visits
  extend ActiveSupport::Concern

  class_methods do
    def report_visits(report)
      report.modes = [Report::MODES[:stacked_chart]]
      report.default_group_by = "weekly"
      report.icon = "user"

      group_filter = report.filters.dig(:group)
      report.add_filter("group", type: "group", default: group_filter)

      desktop_data =
        UserVisit
          .where(mobile: false)
          .where("visited_at >= ? AND visited_at <= ?", report.start_date, report.end_date)
          .group(:visited_at)
          .order(:visited_at)
          .count
          .map { |date, count| { x: date.to_s, y: count } }

      mobile_data =
        UserVisit
          .where(mobile: true)
          .where("visited_at >= ? AND visited_at <= ?", report.start_date, report.end_date)
          .group(:visited_at)
          .order(:visited_at)
          .count
          .map { |date, count| { x: date.to_s, y: count } }

      if group_filter.present?
        group_id = group_filter.to_i
        desktop_data =
          UserVisit
            .joins(user: :group_users)
            .where(mobile: false, group_users: { group_id: group_id })
            .where("visited_at >= ? AND visited_at <= ?", report.start_date, report.end_date)
            .group(:visited_at)
            .order(:visited_at)
            .count
            .map { |date, count| { x: date.to_s, y: count } }

        mobile_data =
          UserVisit
            .joins(user: :group_users)
            .where(mobile: true, group_users: { group_id: group_id })
            .where("visited_at >= ? AND visited_at <= ?", report.start_date, report.end_date)
            .group(:visited_at)
            .order(:visited_at)
            .count
            .map { |date, count| { x: date.to_s, y: count } }
      end

      report.data = [
        {
          req: "desktop",
          label: I18n.t("reports.visits.xaxis.desktop"),
          color: report.colors[:turquoise],
          data: desktop_data,
        },
        {
          req: "mobile",
          label: I18n.t("reports.visits.xaxis.mobile"),
          color: report.colors[:lime],
          data: mobile_data,
        },
      ]

      total_visits =
        UserVisit.where("visited_at >= ? AND visited_at <= ?", report.start_date, report.end_date)
      report.total = total_visits.count

      report.prev30Days =
        UserVisit.where(
          "visited_at >= ? AND visited_at < ?",
          report.start_date - 30.days,
          report.start_date,
        ).count
    end
  end
end

#  basic_report_about report,
#                          UserVisit,
#                          :by_day,
#                          report.start_date,
#                          report.end_date,
#                          group_filter
#       add_counts report, UserVisit, "visited_at"
