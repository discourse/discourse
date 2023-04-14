# frozen_string_literal: true

module Reports::TopicsWithNoResponse
  extend ActiveSupport::Concern

  class_methods do
    def report_topics_with_no_response(report)
      category_id, include_subcategories = report.add_category_filter

      report.data = []
      Topic
        .with_no_response_per_day(
          report.start_date,
          report.end_date,
          category_id,
          include_subcategories,
        )
        .each { |r| report.data << { x: r["date"], y: r["count"].to_i } }

      report.total =
        Topic.with_no_response_total(
          category_id: category_id,
          include_subcategories: include_subcategories,
        )

      report.prev30Days =
        Topic.with_no_response_total(
          start_date: report.start_date - 30.days,
          end_date: report.start_date,
          category_id: category_id,
          include_subcategories: include_subcategories,
        )
    end
  end
end
