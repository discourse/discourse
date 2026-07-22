# frozen_string_literal: true

class AdminDashboardSiteTraffic
  DEFAULT_RANGE_DAYS = 30
  TOP_CARD_LIMIT = 5
  SERIES_LABEL_REQS = {
    logged_in: "page_view_logged_in_browser",
    anonymous: "page_view_anon_browser",
    embedded: "page_view_embed",
    crawlers: "page_view_crawler",
  }.freeze
  private_constant :DEFAULT_RANGE_DAYS
  private_constant :TOP_CARD_LIMIT
  private_constant :SERIES_LABEL_REQS

  def self.build(start_date:, end_date:, guardian:)
    new(start_date: start_date, end_date: end_date, guardian: guardian).build
  end

  def initialize(start_date:, end_date:, guardian:)
    @guardian = guardian
    @start_date = parse_date(start_date) || (DEFAULT_RANGE_DAYS - 1).days.ago.beginning_of_day
    @end_date = parse_date(end_date)&.end_of_day || Time.zone.now.end_of_day

    if @start_date.to_date > @end_date.to_date
      @start_date = (DEFAULT_RANGE_DAYS - 1).days.ago.beginning_of_day
      @end_date = Time.zone.now.end_of_day
    end
  end

  def build
    if async_queries_available?
      current_rows_result = async_traffic_rows(start_date.to_date, end_date.to_date)
      prior_rows_result = async_traffic_rows(prior_start_date, prior_end_date)
      current_rows = current_rows_result.value
      prior_rows = prior_rows_result.value
    else
      current_rows = traffic_rows(start_date.to_date, end_date.to_date)
      prior_rows = traffic_rows(prior_start_date, prior_end_date)
    end
    include_embedded = include_embedded_series?
    totals = build_totals(current_rows, include_embedded: include_embedded)

    response = {
      kpis: kpis(totals, prior_rows),
      pageview_series: pageview_series(current_rows, include_embedded: include_embedded),
    }

    if SiteSetting.persist_browser_pageview_events
      top_countries = fetch_card("top_countries_by_browser_pageviews")
      response[:top_countries] = top_countries if top_countries

      top_referrers = fetch_card("top_referrers_by_browser_pageviews")
      response[:top_referrers] = top_referrers if top_referrers
    end

    response
  end

  private

  attr_reader :start_date, :end_date, :guardian

  def fetch_card(type)
    return nil if Report.hidden?(type, guardian: guardian)

    opts = {
      start_date: start_date,
      end_date: end_date,
      guardian: guardian,
      filters: {
        login_required: SiteSetting.login_required,
        host: Discourse.current_hostname,
      },
      wrap_exceptions_in_test: true,
    }

    cached = Report.find_cached(type, opts)
    return cached_to_payload(cached) if cached

    report = Report.find(type, opts)
    return { rows: [], error: "exception" } if report.nil?

    # Timeouts skip the cache so the next request retries instead of being
    # pinned to the error for the full 35-minute TTL.
    Report.cache(report) if report.error != :timeout

    return { rows: [], error: report.error.to_s } if report.error.present?

    { rows: report.data.first(TOP_CARD_LIMIT), error: nil }
  end

  def cached_to_payload(cached)
    error = cached[:error]
    return { rows: [], error: error.to_s } if error.present?

    { rows: (cached[:data] || []).map(&:symbolize_keys).first(TOP_CARD_LIMIT), error: nil }
  end

  def series_ids(include_embedded:)
    series = %i[logged_in]

    return series if login_required?

    series << :anonymous
    series << :embedded if include_embedded
    series << :crawlers

    series
  end

  def kpis(totals, prior_rows)
    kpis = { browser_pageviews: browser_pageviews_kpi(totals, prior_rows) }
    logged_in_share = logged_in_share_value(totals)

    kpis[:logged_in_share] = { value: logged_in_share } if !logged_in_share.nil?

    direct_traffic = direct_traffic_value
    kpis[:direct_traffic] = { value: direct_traffic } if !direct_traffic.nil?

    if SiteSetting.persist_browser_pageview_events
      kpis[:bounce_rate] = { value: bounce_rate_value }
      kpis[:average_session_duration_seconds] = { value: average_session_duration_value }
    end

    kpis
  end

  def bounce_rate_value
    sessions = session_engagement_totals[:sessions]
    return nil if sessions.zero?

    ((session_engagement_totals[:bounced].to_f / sessions) * 100).round
  end

  def average_session_duration_value
    sessions = session_engagement_totals[:sessions]
    return nil if sessions.zero?

    (session_engagement_totals[:engaged_seconds_total].to_f / sessions).round
  end

  def session_engagement_totals
    @session_engagement_totals ||=
      DB
        .query_hash(<<~SQL, start_date: start_date.to_date, end_date: end_date.to_date)
          SELECT
            COALESCE(SUM(sessions), 0)::bigint AS sessions,
            COALESCE(SUM(bounced), 0)::bigint AS bounced,
            COALESCE(SUM(engaged_seconds_total), 0)::bigint AS engaged_seconds_total
          FROM browser_pageview_session_engagement_daily_rollups
          WHERE date >= :start_date
            AND date <= :end_date
        SQL
        .first
        .symbolize_keys
  end

  def browser_pageviews_kpi(totals, prior_rows)
    kpi = { value: totals[:human] }
    trend = build_trend(totals, prior_rows)

    return kpi if trend.blank?

    kpi.merge(trend)
  end

  def logged_in_share_value(totals)
    return nil if login_required?

    totals[:human].positive? ? ((totals[:logged_in].to_f / totals[:human]) * 100).round : 0
  end

  def direct_traffic_value
    return nil if !SiteSetting.persist_browser_pageview_events

    count_column = login_required? ? "logged_in_count" : "count"

    row = DB.query(<<~SQL, start_date: start_date.to_date, end_date: end_date.to_date).first
          SELECT
            COALESCE(SUM(#{count_column}), 0)::bigint AS total,
            COALESCE(SUM(#{count_column}) FILTER (WHERE normalized_referrer IS NULL), 0)::bigint AS direct
          FROM browser_pageview_referrer_daily_rollups
          WHERE date >= :start_date
            AND date <= :end_date
        SQL

    return nil if row.total.zero?

    ((row.direct.to_f / row.total) * 100).round
  end

  def pageview_series(rows, include_embedded:)
    series_ids(include_embedded: include_embedded).map do |id|
      {
        req: series_req(id),
        label: series_label(id),
        color: series_color(id),
        data: rows.map { |row| pageview_series_point(row, id) },
      }
    end
  end

  def pageview_series_point(row, id)
    { x: row_value(row, :date).iso8601, y: row_value(row, id).to_i }
  end

  def series_req(id)
    selected_request_type_names.fetch(id)
  end

  def series_label(id)
    I18n.t("reports.site_traffic.xaxis.#{series_label_req(id)}")
  end

  def series_label_req(id)
    SERIES_LABEL_REQS.fetch(id)
  end

  def series_color(id)
    Reports::SiteTraffic::SERIES_COLORS.fetch(series_label_req(id))
  end

  def login_required?
    SiteSetting.login_required
  end

  def prior_start_date
    prior_end_date - (selected_day_count - 1)
  end

  def prior_end_date
    start_date.to_date - 1
  end

  def prior_period_complete?
    prior_period_tracking_started?
  end

  def prior_period_tracking_started?
    return @prior_period_tracking_started if defined?(@prior_period_tracking_started)

    req_type_sql =
      if login_required?
        "req_type = :logged_in_req_type"
      else
        "req_type IN (:logged_in_req_type, :anonymous_req_type)"
      end

    @prior_period_tracking_started =
      DB.query_single(
        <<~SQL,
          SELECT 1
          FROM application_requests
          WHERE date <= :prior_start_date
            AND #{req_type_sql}
          LIMIT 1
        SQL
        prior_start_date: prior_start_date,
        logged_in_req_type: selected_request_types[:logged_in],
        anonymous_req_type: selected_request_types[:anonymous],
      ).present?
  end

  def parse_date(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)&.beginning_of_day
  rescue ArgumentError, TypeError
    nil
  end

  def selected_request_types
    @selected_request_types ||=
      selected_request_type_names.transform_values { |name| ApplicationRequest.req_types[name] }
  end

  def selected_request_type_names
    @selected_request_type_names ||=
      if SiteSetting.use_legacy_pageviews
        { logged_in: "page_view_logged_in", anonymous: "page_view_anon" }
      else
        { logged_in: "page_view_logged_in_browser", anonymous: "page_view_anon_browser" }
      end.merge(crawlers: "page_view_crawler", embedded: "page_view_embed")
  end

  def async_queries_available?
    executor = ActiveRecord::Base.connection_pool.async_executor
    executor && executor.max_length > 1
  end

  def async_traffic_rows(range_start_date, range_end_date)
    sql =
      ActiveRecord::Base.sanitize_sql(
        [traffic_rows_sql, traffic_rows_params(range_start_date, range_end_date)],
      )
    ActiveRecord::Base
      .connection
      .select_all(sql, "Admin Dashboard Traffic", [], async: true)
      .then { |result| result.to_a.map(&:symbolize_keys) }
  end

  def traffic_rows(range_start_date, range_end_date)
    DB.query(traffic_rows_sql, traffic_rows_params(range_start_date, range_end_date))
  end

  def traffic_rows_sql
    <<~SQL
        WITH dates AS (
          SELECT
            request_date::date AS date
          FROM generate_series(
            CAST(:start_date AS date),
            CAST(:end_date AS date),
            INTERVAL '1 day'
          ) request_date
        )
        SELECT
          dates.date,
          COALESCE(SUM(CASE WHEN ar.req_type = :logged_in_req_type THEN ar.count ELSE 0 END), 0)::bigint AS logged_in,
          COALESCE(SUM(CASE WHEN ar.req_type = :anonymous_req_type THEN ar.count ELSE 0 END), 0)::bigint AS anonymous,
          COALESCE(SUM(CASE WHEN ar.req_type = :crawler_req_type THEN ar.count ELSE 0 END), 0)::bigint AS crawlers,
          COALESCE(SUM(CASE WHEN ar.req_type = :embedded_req_type THEN ar.count ELSE 0 END), 0)::bigint AS embedded
        FROM dates
        LEFT JOIN application_requests ar
          ON ar.date = dates.date
          AND ar.req_type IN (
            :logged_in_req_type,
            :anonymous_req_type,
            :crawler_req_type,
            :embedded_req_type
          )
        GROUP BY dates.date
        ORDER BY dates.date ASC
    SQL
  end

  def traffic_rows_params(range_start_date, range_end_date)
    {
      start_date: range_start_date,
      end_date: range_end_date,
      logged_in_req_type: selected_request_types[:logged_in],
      anonymous_req_type: selected_request_types[:anonymous],
      crawler_req_type: selected_request_types[:crawlers],
      embedded_req_type: selected_request_types[:embedded],
    }
  end

  def build_totals(rows, include_embedded:)
    logged_in = sum_rows(rows, :logged_in)
    anonymous = login_required? ? 0 : sum_rows(rows, :anonymous)
    crawlers = login_required? ? 0 : sum_rows(rows, :crawlers)
    embedded = include_embedded ? sum_rows(rows, :embedded) : 0

    {
      logged_in: logged_in,
      anonymous: anonymous,
      embedded: embedded,
      crawlers: crawlers,
      human: logged_in + anonymous,
    }
  end

  def build_trend(totals, prior_rows)
    return nil if !prior_period_complete?

    current_human = totals[:human]
    previous_human = prior_human(prior_rows)
    return nil if previous_human.zero? || current_human == previous_human

    percent_change = ((current_human - previous_human).to_f / previous_human) * 100
    return nil if percent_change.abs < 0.05

    {
      percent_change: format_trend_percent_change(percent_change),
      comparison_period: {
        start_date: prior_start_date.iso8601,
        end_date: prior_end_date.iso8601,
      },
    }
  end

  def prior_human(prior_rows)
    logged_in = sum_rows(prior_rows, :logged_in)
    anonymous = login_required? ? 0 : sum_rows(prior_rows, :anonymous)

    logged_in + anonymous
  end

  def format_trend_percent_change(percent_change)
    percent_change.abs < 1 ? percent_change.round(1) : percent_change.round
  end

  def sum_rows(rows, field)
    rows.sum { |row| row_value(row, field).to_i }
  end

  def row_value(row, field)
    row.respond_to?(field) ? row.public_send(field) : row.fetch(field)
  end

  def include_embedded_series?
    !login_required? && embedding_enabled? && EmbeddableHost.exists?
  end

  def embedding_enabled?
    SiteSetting.embed_topics_list || SiteSetting.embed_full_app
  end

  def selected_day_count
    (end_date.to_date - start_date.to_date).to_i + 1
  end
end
