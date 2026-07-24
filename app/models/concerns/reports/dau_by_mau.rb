# frozen_string_literal: true

module Reports::DauByMau
  extend ActiveSupport::Concern

  class_methods do
    def report_dau_by_mau(report)
      report.labels = [
        { type: :date, property: :x, title: I18n.t("reports.default.labels.day") },
        { type: :percent, property: :y, title: I18n.t("reports.default.labels.percent") },
      ]

      report.average = true
      report.percent = true

      data_start = report.facets.include?(:prev_period) ? report.prev_start_date : report.start_date
      data_points = dau_mau_data_points(start_date: data_start, end_date: report.end_date)

      report.data = []

      compute_dau_by_mau =
        Proc.new do |data_point|
          if data_point["mau"] == 0
            0
          else
            ((data_point["dau"].to_f / data_point["mau"].to_f) * 100).ceil(2)
          end
        end

      dau_avg =
        Proc.new do |points|
          if !points.empty?
            sum = points.sum { |data_point| compute_dau_by_mau.call(data_point) }
            (sum.to_f / points.count.to_f).ceil(2)
          end
        end

      if report.facets.include?(:prev_period)
        current_start = report.start_date.to_date
        data_points, prev_data_points =
          data_points.partition { |data_point| data_point["date"].to_date >= current_start }
        report.prev_period = dau_avg.call(prev_data_points)
      end

      data_points.each do |data_point|
        report.data << { x: data_point["date"], y: compute_dau_by_mau.call(data_point) }
      end

      if report.facets.include?(:prev30Days)
        prev30_days_data =
          dau_mau_data_points(start_date: report.start_date - 30.days, end_date: report.start_date)
        report.prev30Days = dau_avg.call(prev30_days_data)
      end
    end

    private

    def dau_mau_data_points(start_date:, end_date:)
      UserVisitDailyRollup.fetch(start_date: start_date, end_date: end_date)
    end
  end
end
