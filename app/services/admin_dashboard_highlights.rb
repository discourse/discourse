# frozen_string_literal: true

class AdminDashboardHighlights
  DEFAULT_RANGE_DAYS = 30

  KPI_REPORTS = {
    new_signups: "signups",
    dau_mau: "dau_by_mau",
    new_contributors: "new_contributors",
  }.freeze

  def self.build(start_date:, end_date:)
    new(start_date: start_date, end_date: end_date).build
  end

  def initialize(start_date:, end_date:)
    @start_date = parse_date(start_date) || DEFAULT_RANGE_DAYS.days.ago.beginning_of_day
    @end_date = parse_date(end_date)&.end_of_day || Time.zone.now.end_of_day
  end

  def build
    { kpis: build_kpis }
  end

  private

  attr_reader :start_date, :end_date

  def parse_date(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s)&.beginning_of_day
  rescue ArgumentError, TypeError
    nil
  end

  def build_kpis
    core_kpis = KPI_REPORTS.map { |type, report| { type: type, report: report } }
    all_kpis = core_kpis + DiscoursePluginRegistry.admin_dashboard_highlight_kpis

    all_kpis.filter_map do |kpi|
      next if kpi[:enabled].respond_to?(:call) && !kpi[:enabled].call
      build_kpi(kpi[:type], kpi[:report])
    end
  end

  def build_kpi(type, report_name)
    args = { start_date: start_date, end_date: end_date, facets: %i[prev_period] }

    report = Report.find_cached(report_name, args)
    if report.nil?
      report = Report.find(report_name, args)
      Report.cache(report) if report && report.error.blank?
    end

    return nil if report.nil? || report_error?(report) || report_data(report).nil?

    current = period_value(type, report_data(report))
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

  # Report.find returns a Report object
  # Report.find_cached returns the as_json hash (symbol-keyed).
  # The accessors below cope with either
  def report_error?(report_or_hash)
    report_or_hash.is_a?(Hash) ? report_or_hash[:error].present? : report_or_hash.error.present?
  end

  def report_data(report_or_hash)
    report_or_hash.is_a?(Hash) ? report_or_hash[:data] : report_or_hash.data
  end

  def report_prev_period(report_or_hash)
    if report_or_hash.is_a?(Hash)
      report_or_hash[:prev_period]
    else
      report_or_hash.prev_period
    end
  end

  def period_value(type, data)
    return nil if data.empty?

    ys = data.map { |point| point[:y] }

    if type == :dau_mau
      (ys.sum(&:to_f) / ys.size).round(1)
    else
      ys.sum(&:to_i)
    end
  end

  def compute_percent_change(current, previous)
    return nil if previous.blank? || previous.zero? || current.blank?
    ((current.to_f - previous) / previous * 100).round(2)
  end
end
