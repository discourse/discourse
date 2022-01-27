# frozen_string_literal: true

module Reports::TimeToFirstResponse
  extend ActiveSupport::Concern

  class_methods do
    def report_time_to_first_response(report)
      category_filter = report.filters.dig(:category)
      category_id, include_subcategories = report.add_category_filter

      report.icon = 'reply'
      report.higher_is_better = false
      report.data = []
      report.average = true

      Topic.time_to_first_response_per_day(report.start_date, report.end_date, category_id: category_id, include_subcategories: include_subcategories).each do |r|
        report.data << { x: r['date'], y: r['hours'].to_f.round(2) }
      end

      report.total = Topic.time_to_first_response_total(category_id: category_id, include_subcategories: include_subcategories)

      report.prev30Days = Topic.time_to_first_response_total(start_date: report.start_date - 30.days, end_date: report.start_date, category_id: category_id, include_subcategories: include_subcategories)
    end
  end
end
