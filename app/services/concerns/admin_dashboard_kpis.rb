# frozen_string_literal: true

# Including classes must expose `start_date` and `end_date`.
module AdminDashboardKpis
  private

  def build_kpi(type, report_name)
    args = { start_date: start_date, end_date: end_date, facets: %i[prev_period] }

    report = Report.find_cached(report_name, args)
    if report.nil?
      report = Report.find(report_name, args)
      Report.cache(report) if report && report.error.blank?
    end

    return nil if report.nil? || report_error?(report) || report_data(report).nil?

    current = period_value(report_data(report), average: report_average?(report))
    previous = report_prev_period(report)

    {
      type: type,
      value: current,
      previous_value: previous,
      percent_change: compute_percent_change(current, previous),
      report_type: report_name,
      report_query: {
        start_date: start_date.to_date.iso8601,
        end_date: end_date.to_date.iso8601,
      },
    }
  end

  # Report.find returns a Report object; Report.find_cached returns the as_json
  # hash (symbol-keyed). The accessors below cope with either.
  def report_error?(report_or_hash)
    report_or_hash.is_a?(Hash) ? report_or_hash[:error].present? : report_or_hash.error.present?
  end

  def report_data(report_or_hash)
    report_or_hash.is_a?(Hash) ? report_or_hash[:data] : report_or_hash.data
  end

  def report_prev_period(report_or_hash)
    report_or_hash.is_a?(Hash) ? report_or_hash[:prev_period] : report_or_hash.prev_period
  end

  def report_average?(report_or_hash)
    report_or_hash.is_a?(Hash) ? report_or_hash[:average] : report_or_hash.average
  end

  def period_value(data, average:)
    return nil if data.empty?

    ys = data.map { |point| point[:y] }
    return (ys.sum(&:to_f) / ys.size).round(1) if average

    ys.sum(&:to_i)
  end

  def compute_percent_change(current, previous)
    return nil if previous.blank? || previous.zero? || current.blank?
    ((current.to_f - previous) / previous * 100).round(2)
  end
end
