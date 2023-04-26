# frozen_string_literal: true

module Reports::TopTrafficSources
  extend ActiveSupport::Concern

  class_methods do
    def report_top_traffic_sources(report)
      category_id, include_subcategories = report.add_category_filter

      report.modes = [:table]

      report.labels = [
        { property: :domain, title: I18n.t("reports.top_traffic_sources.labels.domain") },
        {
          property: :num_clicks,
          type: :number,
          title: I18n.t("reports.top_traffic_sources.labels.num_clicks"),
        },
        {
          property: :num_topics,
          type: :number,
          title: I18n.t("reports.top_traffic_sources.labels.num_topics"),
        },
      ]

      options = {
        end_date: report.end_date,
        start_date: report.start_date,
        limit: report.limit || 8,
        category_id: category_id,
        include_subcategories: include_subcategories,
      }

      result = IncomingLinksReport.find(:top_traffic_sources, options)
      report.data = result.data
    end
  end
end
