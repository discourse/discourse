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

  def self.build(start_date:, end_date:)
    new(start_date: start_date, end_date: end_date).build
  end

  def initialize(start_date:, end_date:)
    @start_date = parse_date(start_date) || (DEFAULT_RANGE_DAYS - 1).days.ago.beginning_of_day
    @end_date = parse_date(end_date)&.end_of_day || Time.zone.now.end_of_day

    if @start_date.to_date > @end_date.to_date
      @start_date = (DEFAULT_RANGE_DAYS - 1).days.ago.beginning_of_day
      @end_date = Time.zone.now.end_of_day
    end
  end

  def build
    current_rows = traffic_rows(start_date.to_date, end_date.to_date)
    prior_rows = traffic_rows(prior_start_date, prior_end_date)
    include_embedded = include_embedded_series?
    totals = build_totals(current_rows, include_embedded: include_embedded)

    response = {
      kpis: kpis(totals, prior_rows),
      pageview_series: pageview_series(current_rows, include_embedded: include_embedded),
    }

    if SiteSetting.persist_browser_pageview_events
      response[:top_countries] = fetch_card("top_countries_by_browser_pageviews")
      response[:top_referrers] = top_referrers_card
    end

    response
  end

  private

  attr_reader :start_date, :end_date

  def fetch_card(type)
    opts = {
      start_date: start_date,
      end_date: end_date,
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

  # The Top referrers card surfaces Direct (no referrer) alongside the external
  # referrers, with every percentage sharing one denominator (direct +
  # external-referred, own host excluded). This denominator differs from the
  # standalone report's (referred-only), so the card owns its own SQL rather
  # than reusing the report's row contract.
  def top_referrers_card
    direct_count, external_total, external_rows = referrer_universe
    total = direct_count + external_total

    return { rows: [], error: nil } if total.zero?

    rows = [direct_row(direct_count, total)]
    rows.concat(external_rows.first(TOP_CARD_LIMIT).map { |row| external_referrer_row(row, total) })

    { rows: rows, error: nil }
  end

  def referrer_universe
    host = BrowserPageviewReferrerInspector.normalize_host(Discourse.current_hostname)
    escaped_host = host.gsub(/[\\_%]/) { |char| "\\#{char}" }
    count_expr = login_required? ? "logged_in_count" : "count"

    rows =
      DB.query(
        <<~SQL,
          SELECT
            normalized_referrer IS NULL AS direct,
            normalized_referrer,
            SUM(#{count_expr})::bigint AS count
          FROM browser_pageview_referrer_daily_rollups
          WHERE date >= :start_date
            AND date < :end_date_exclusive
            AND (
              normalized_referrer IS NULL
              OR (
                normalized_referrer <> :host_exact
                AND normalized_referrer NOT LIKE :host_path_prefix ESCAPE '\\'
                AND normalized_referrer NOT LIKE :host_query_prefix ESCAPE '\\'
              )
            )
          GROUP BY normalized_referrer
          HAVING SUM(#{count_expr}) > 0
          ORDER BY count DESC, normalized_referrer ASC
        SQL
        start_date: start_date.to_date,
        end_date_exclusive: end_date.to_date + 1,
        host_exact: host,
        host_path_prefix: "#{escaped_host}/%",
        host_query_prefix: "#{escaped_host}?%",
      )

    direct_count = rows.find(&:direct)&.count.to_i
    external_rows = rows.reject(&:direct)
    external_total = external_rows.sum(&:count)

    [direct_count, external_total, external_rows]
  end

  def direct_row(count, total)
    { direct: true, count: count, percent: percent_of(count, total) }
  end

  def external_referrer_row(row, total)
    {
      normalized_referrer: row.normalized_referrer,
      count: row.count,
      percent: percent_of(row.count, total),
    }
  end

  def percent_of(count, total)
    total.zero? ? 0 : ((count.to_f / total) * 100).round
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

    kpis
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
    { x: row.date.iso8601, y: row.public_send(id).to_i }
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

  def traffic_rows(range_start_date, range_end_date)
    DB.query(
      <<~SQL,
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
      start_date: range_start_date,
      end_date: range_end_date,
      logged_in_req_type: selected_request_types[:logged_in],
      anonymous_req_type: selected_request_types[:anonymous],
      crawler_req_type: selected_request_types[:crawlers],
      embedded_req_type: selected_request_types[:embedded],
    )
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
    rows.sum { |row| row.public_send(field).to_i }
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
