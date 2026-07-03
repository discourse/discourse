# frozen_string_literal: true

module Reports::DailyEngagedUsers
  extend ActiveSupport::Concern

  class_methods do
    def report_daily_engaged_users(report)
      report.average = true

      report.data = []

      data_start = report.facets.include?(:prev_period) ? report.prev_start_date : report.start_date
      data = UserAction.count_daily_engaged_users(data_start, report.end_date)

      if report.facets.include?(:prev30Days)
        prev30DaysData =
          UserAction.count_daily_engaged_users(report.start_date - 30.days, report.start_date)
        report.prev30Days = prev30DaysData.sum { |k, v| v }
      end

      report.total = UserAction.count_daily_engaged_users if report.facets.include?(:total)

      if report.facets.include?(:prev_period)
        data, prev_data = split_date_counts(data, report.start_date)
        prev = prev_data.sum { |_date, count| count }
        report.prev_period = prev.zero? ? prev : (prev.to_f / prev_data.size).round(1)
      end

      data.each { |key, value| report.data << { x: key, y: value } }
    end
  end
end
