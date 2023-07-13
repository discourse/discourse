# frozen_string_literal: true

module Reports::WebCrawlers
  extend ActiveSupport::Concern

  class_methods do
    def report_web_crawlers(report)
      report.labels = [
        {
          type: :string,
          property: :user_agent,
          title: I18n.t("reports.web_crawlers.labels.user_agent"),
        },
        {
          property: :count,
          type: :number,
          title: I18n.t("reports.web_crawlers.labels.page_views"),
        },
      ]

      report.modes = [:table]

      report.data =
        WebCrawlerRequest
          .where("date >= ? and date <= ?", report.start_date, report.end_date)
          .limit(200)
          .order("sum_count DESC")
          .group(:user_agent)
          .sum(:count)
          .map { |ua, count| { user_agent: ua, count: count } }
    end
  end
end
