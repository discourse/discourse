# frozen_string_literal: true

class AdminDashboardSearch
  DEFAULT_RANGE_DAYS = 30
  TOP_TERMS_LIMIT = 10
  ALARM_THRESHOLD_PERCENT = 10
  POOR_MATCH_MAX_CTR_PERCENT = 20
  TRENDING_PERIODS_BY_MAX_DAYS = {
    7 => "weekly",
    31 => "monthly",
    92 => "quarterly",
    366 => "yearly",
  }.freeze
  private_constant :DEFAULT_RANGE_DAYS,
                   :TOP_TERMS_LIMIT,
                   :ALARM_THRESHOLD_PERCENT,
                   :POOR_MATCH_MAX_CTR_PERCENT,
                   :TRENDING_PERIODS_BY_MAX_DAYS

  def self.build(start_date:, end_date:)
    new(start_date: start_date, end_date: end_date).build
  end

  def initialize(start_date:, end_date:)
    @start_date = parse_date(start_date) || default_start_date
    @end_date = parse_date(end_date)&.end_of_day || Time.zone.now.end_of_day

    if @start_date.to_date > @end_date.to_date
      @start_date = default_start_date
      @end_date = Time.zone.now.end_of_day
    end
  end

  def build
    return { logging_enabled: false } if !SiteSetting.log_search_queries

    if async_queries_available?
      current_stats = async_window_stats(window_start: start_date, window_end: end_date)
      prior_stats = async_window_stats(window_start: prior_start_date, window_end: prior_end_date)
      trending_rows = trending_relation.load_async
      content_gap_rows = content_gaps_relation.load_async

      current = current_stats.value
      prior = prior_stats.value
    else
      current = window_stats(window_start: start_date, window_end: end_date)
      prior = window_stats(window_start: prior_start_date, window_end: prior_end_date)
      trending_rows = trending_relation
      content_gap_rows = content_gaps_relation
    end
    kpis = build_kpis(current: current, prior: prior)

    {
      logging_enabled: true,
      headline_state: headline_state(current: current, kpis: kpis),
      kpis: kpis,
      trending: serialize_trending(trending_rows),
      trending_period: trending_period,
      content_gaps: serialize_content_gaps(content_gap_rows),
    }
  end

  private

  attr_reader :start_date, :end_date

  def build_kpis(current:, prior:)
    {
      total_searches: total_searches_kpi(current: current, prior: prior),
      no_result_rate: no_result_rate_kpi(current: current, prior: prior),
    }
  end

  def total_searches_kpi(current:, prior:)
    kpi = { value: current[:total] }

    if current[:total].positive? && prior[:total].positive?
      change = formatted_change((current[:total] - prior[:total]) * 100.0 / prior[:total])
      kpi[:percent_change] = change if change
    end

    kpi
  end

  def no_result_rate_kpi(current:, prior:)
    return { value: nil, exceeds_threshold: false } if current[:total].zero?

    kpi = {
      value: no_result_rate(current).round,
      exceeds_threshold: current[:no_match] * 100 > current[:total] * ALARM_THRESHOLD_PERCENT,
    }

    if prior[:total].positive?
      change = formatted_change(no_result_rate(current) - no_result_rate(prior))
      kpi[:point_change] = change if change
    end

    kpi
  end

  def no_result_rate(stats)
    stats[:no_match] * 100.0 / stats[:total]
  end

  def formatted_change(value)
    rounded = value.abs < 1 ? value.round(1) : value.round
    rounded.zero? ? nil : rounded
  end

  def headline_state(current:, kpis:)
    return "no_signal" if current[:total].zero?
    return "content_gaps" if kpis[:no_result_rate][:exceeds_threshold]
    return "rate_climbing" if kpis[:no_result_rate][:point_change].to_f.positive?
    return "shrinking" if kpis[:total_searches][:percent_change].to_f.negative?

    "healthy"
  end

  def trending_relation
    non_staff_search_logs_in(window_start: start_date, window_end: end_date)
      .select(<<~SQL)
        lower(search_logs.term) AS term,
        COUNT(*) AS searches,
        SUM(CASE WHEN search_result_id IS NOT NULL THEN 1 ELSE 0 END) AS clicks
      SQL
      .group("lower(search_logs.term)")
      .order("searches DESC, clicks DESC, term ASC")
      .limit(TOP_TERMS_LIMIT)
  end

  def serialize_trending(rows)
    rows.map { |row| { term: row.term, searches: row.searches } }
  end

  def trending_period
    TRENDING_PERIODS_BY_MAX_DAYS.each do |max_days, period|
      return period if selected_day_count <= max_days
    end

    "all"
  end

  def content_gaps_relation
    non_staff_search_logs_in(window_start: start_date, window_end: end_date)
      .select(<<~SQL)
        lower(search_logs.term) AS term,
        COUNT(*) AS searches,
        SUM(CASE WHEN search_result_id IS NOT NULL THEN 1 ELSE 0 END) AS clicks
      SQL
      .group("lower(search_logs.term)")
      .having(<<~SQL, POOR_MATCH_MAX_CTR_PERCENT)
        SUM(CASE WHEN search_result_id IS NOT NULL THEN 1 ELSE 0 END) * 100 <=
          COUNT(*) * ?
      SQL
      .order("searches DESC, term ASC")
      .limit(TOP_TERMS_LIMIT)
  end

  def serialize_content_gaps(rows)
    rows.map do |row|
      {
        term: row.term,
        searches: row.searches,
        status: row.clicks.to_i.zero? ? "no_match" : "poor_match",
      }
    end
  end

  def async_queries_available?
    executor = ActiveRecord::Base.connection_pool.async_executor
    executor && executor.max_length > 1
  end

  def async_window_stats(window_start:, window_end:)
    window_stats_relation(window_start: window_start, window_end: window_end)
      .async_pick(
        "COALESCE(SUM(searches), 0)::bigint",
        "COALESCE(SUM(CASE WHEN clicks = 0 THEN searches ELSE 0 END), 0)::bigint",
      )
      .then { |total, no_match| { total: total, no_match: no_match } }
  end

  def window_stats(window_start:, window_end:)
    row =
      window_stats_relation(window_start: window_start, window_end: window_end).select(<<~SQL).take
          COALESCE(SUM(searches), 0)::bigint AS total,
          COALESCE(SUM(CASE WHEN clicks = 0 THEN searches ELSE 0 END), 0)::bigint AS no_match
        SQL

    { total: row.total, no_match: row.no_match }
  end

  def window_stats_relation(window_start:, window_end:)
    term_stats =
      non_staff_search_logs_in(window_start: window_start, window_end: window_end).select(
        <<~SQL,
          COUNT(*) AS searches,
          SUM(CASE WHEN search_result_id IS NOT NULL THEN 1 ELSE 0 END) AS clicks
        SQL
      ).group("lower(search_logs.term)")

    SearchLog.from("(#{term_stats.to_sql}) term_stats")
  end

  def non_staff_search_logs_in(window_start:, window_end:)
    SearchLog.non_staff.where(created_at: window_start..window_end)
  end

  def parse_date(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)&.beginning_of_day
  rescue ArgumentError, TypeError
    nil
  end

  def default_start_date
    (DEFAULT_RANGE_DAYS - 1).days.ago.beginning_of_day
  end

  def prior_start_date
    (start_date.to_date - selected_day_count).beginning_of_day
  end

  def prior_end_date
    (start_date.to_date - 1).end_of_day
  end

  def selected_day_count
    (end_date.to_date - start_date.to_date).to_i + 1
  end
end
