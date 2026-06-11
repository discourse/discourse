# frozen_string_literal: true

module Reports::NewContributors
  extend ActiveSupport::Concern

  class_methods do
    def report_new_contributors(report)
      report.data = []

      data_start = report.facets.include?(:prev_period) ? report.prev_start_date : report.start_date
      data = User.real.count_by_first_post(data_start, report.end_date)

      if report.facets.include?(:prev30Days)
        prev30DaysData =
          User.real.count_by_first_post(report.start_date - 30.days, report.start_date)
        report.prev30Days = prev30DaysData.sum { |k, v| v }
      end

      report.total = User.real.count_by_first_post if report.facets.include?(:total)

      if report.facets.include?(:prev_period)
        data, prev_period_data = split_date_counts(data, report.start_date)
        report.prev_period = prev_period_data.sum { |_date, count| count }
      end

      data.each { |key, value| report.data << { x: key, y: value } }
    end
  end
end
