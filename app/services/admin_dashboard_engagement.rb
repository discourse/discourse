# frozen_string_literal: true

class AdminDashboardEngagement
  include AdminDashboardKpis

  DEFAULT_RANGE_DAYS = 30

  KPI_REPORTS = {
    dau_mau: "dau_by_mau",
    daily_engaged_users: "daily_engaged_users",
    new_signups: "signups",
  }.freeze

  def self.build(start_date:, end_date:, current_user: nil)
    new(start_date: start_date, end_date: end_date, current_user: current_user).build
  end

  def initialize(start_date:, end_date:, current_user: nil)
    @start_date = parse_date(start_date) || DEFAULT_RANGE_DAYS.days.ago.beginning_of_day
    @end_date = parse_date(end_date)&.end_of_day || Time.zone.now.end_of_day
    @current_user = current_user
  end

  def build
    {
      kpis: build_kpis,
      trust_level_pipeline: build_trust_level_pipeline,
      posters: build_posters,
      activity_by_category: build_activity_by_category,
    }
  end

  private

  attr_reader :start_date, :end_date, :current_user

  def parse_date(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s)&.beginning_of_day
  rescue ArgumentError, TypeError
    nil
  end

  def build_kpis
    KPI_REPORTS.filter_map { |type, report| build_kpi(type, report) }
  end

  def build_trust_level_pipeline
    args = { start_date: start_date, end_date: end_date }

    report = Report.find_cached("trust_level_pipeline", args)
    if report.nil?
      report = Report.find("trust_level_pipeline", args)
      Report.cache(report) if report && report.error.blank?
    end

    return nil if report.nil? || report_error?(report)

    {
      rows: report_data(report),
      trend: report_prev_period(report),
      total_members: report.is_a?(Hash) ? report[:total] : report.total,
    }
  end

  def build_posters
    args = { start_date: start_date, end_date: end_date, current_user: current_user }

    selected_category_ids =
      AdminDashboardSectionConfiguration.settings_for("engagement").dig(
        "whos_posting",
        "category_ids",
      )
    args[:filters] = { category_ids: selected_category_ids } if selected_category_ids.present?

    report = Report.find_cached("posters_by_member_type", args)
    if report.nil?
      report = Report.find("posters_by_member_type", args)
      Report.cache(report) if report && report.error.blank?
    end

    return nil if report.nil? || report_error?(report)

    {
      rows: report_data(report),
      total: report.is_a?(Hash) ? report[:total] : report.total,
      category_ids: visible_category_ids(selected_category_ids),
    }
  end

  def build_activity_by_category
    args = { start_date: start_date, end_date: end_date, current_user: current_user }

    selected_category_ids =
      AdminDashboardSectionConfiguration.settings_for("engagement").dig(
        "activity_by_category",
        "category_ids",
      )
    args[:filters] = { category_ids: selected_category_ids } if selected_category_ids.present?

    report = Report.find_cached("activity_by_category", args)
    if report.nil?
      report = Report.find("activity_by_category", args)
      Report.cache(report) if report && report.error.blank?
    end

    return nil if report.nil? || report_error?(report)

    {
      rows: report_data(report),
      total: report.is_a?(Hash) ? report[:total] : report.total,
      category_ids: visible_category_ids(selected_category_ids),
    }
  end

  def visible_category_ids(category_ids)
    return category_ids if category_ids.blank?

    Category.secured(Guardian.new(current_user)).in_order_of(:id, category_ids).pluck(:id)
  end
end
