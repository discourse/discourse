# frozen_string_literal: true

class AdminDashboardHighlights
  include AdminDashboardKpis

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
end
