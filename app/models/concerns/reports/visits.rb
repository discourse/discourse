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

        if report.facets.include?(:prev30Days)
          report.prev30Days =
            UserVisit.where(
              "visited_at >= ? AND visited_at < ?",
              report.start_date - 30.days,
              report.start_date,
            ).count
        end
      end
    end

    private

    def report_visits_stacked(report, group_filter)
      report.modes = [Report::MODES[:stacked_chart]]
      report.default_group_by = "weekly"

      results =
        UserVisit.counts_by_day_and_mobile(
          report.start_date,
          report.end_date,
          group_id: group_filter,
        )

      desktop_data = []
      mobile_data = []

      results.each do |row|
        if row.mobile
          mobile_data << { x: row.visited_at.to_s, y: row.visit_count }
        else
          desktop_data << { x: row.visited_at.to_s, y: row.visit_count }
        end
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

      report.total = results.first&.total || 0

      if report.facets.include?(:prev30Days)
        report.prev30Days =
          UserVisit.where(
            "visited_at >= ? AND visited_at < ?",
            report.start_date - 30.days,
            report.start_date,
          ).count
      end
    end
  end
end
