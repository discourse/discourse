# frozen_string_literal: true

module Reports::Visits
  extend ActiveSupport::Concern

  class_methods do
    def report_visits(report)
      group_filter = report.filters.dig(:group)
      report.add_filter("group", type: "group", default: group_filter)

      report.icon = "user"

      if SiteSetting.reporting_improvements
        report_visits_stacked(report, group_filter)
      else
        basic_report_about report,
                           UserVisit,
                           :by_day,
                           report.start_date,
                           report.end_date,
                           group_filter
        add_counts report, UserVisit, "visited_at"

        report.prev30Days =
          UserVisit.where(
            "visited_at >= ? AND visited_at < ?",
            report.start_date - 30.days,
            report.start_date,
          ).count
      end
    end

    private

    def report_visits_stacked(report, group_filter)
      report.modes = [Report::MODES[:stacked_chart]]
      report.default_group_by = "weekly"

      desktop_data =
        UserVisit
          .desktop_by_day(report.start_date, report.end_date, group_filter)
          .map { |date, count| { x: date.to_s, y: count } }
      mobile_data =
        UserVisit
          .mobile_by_day(report.start_date, report.end_date, group_filter)
          .map { |date, count| { x: date.to_s, y: count } }

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

      report.total =
        UserVisit.where(
          "visited_at >= ? AND visited_at <= ?",
          report.start_date,
          report.end_date,
        ).count

      report.prev30Days =
        UserVisit.where(
          "visited_at >= ? AND visited_at < ?",
          report.start_date - 30.days,
          report.start_date,
        ).count
    end
  end
end
