# frozen_string_literal: true

class AdminDashboardSiteTraffic
  DEFAULT_RANGE_DAYS = 30

  def self.build(start_date:, end_date:)
    new(start_date: start_date, end_date: end_date).build
  end

  def initialize(start_date:, end_date:)
    @start_date = parse_date(start_date) || DEFAULT_RANGE_DAYS.days.ago.beginning_of_day
    @end_date = parse_date(end_date)&.end_of_day || Time.zone.now.end_of_day

    if @start_date.to_date > @end_date.to_date
      @start_date = DEFAULT_RANGE_DAYS.days.ago.beginning_of_day
      @end_date = Time.zone.now.end_of_day
    end
  end

  def build
    current_rows = traffic_rows(start_date.to_date, end_date.to_date)
    prior_rows = traffic_rows(prior_start_date, prior_end_date)
    include_embedded = include_embedded_series?
    totals = build_totals(current_rows, include_embedded: include_embedded)

    {
      kpis: kpis(totals, prior_rows),
      pageview_series: pageview_series(current_rows, include_embedded: include_embedded),
    }
  end

  private

  attr_reader :start_date, :end_date

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
        id: id.to_s,
        default_visible: default_visible_series?(id),
        data: rows.map { |row| pageview_series_point(row, id) },
      }
    end
  end

  def pageview_series_point(row, id)
    point = { date: row.date.iso8601, count: row.public_send(id).to_i }
    point[:end_date] = row.end_date.iso8601 if row.end_date != row.date
    point
  end

  def default_visible_series?(id)
    id != :crawlers
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
    tracking_started_at.present? && prior_start_date >= tracking_started_at
  end

  def tracking_started_at
    @tracking_started_at ||=
      begin
        req_type_sql =
          if login_required?
            "req_type = :logged_in_req_type"
          else
            "req_type IN (:logged_in_req_type, :anonymous_req_type)"
          end

        DB.query_single(
          <<~SQL,
            SELECT MIN(date)
            FROM application_requests
            WHERE #{req_type_sql}
          SQL
          logged_in_req_type: selected_request_types[:logged_in],
          anonymous_req_type: selected_request_types[:anonymous],
        ).first
      end
  end

  def parse_date(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)&.beginning_of_day
  rescue ArgumentError, TypeError
    nil
  end

  def selected_request_types
    @selected_request_types ||=
      if SiteSetting.use_legacy_pageviews
        {
          logged_in: ApplicationRequest.req_types[:page_view_logged_in],
          anonymous: ApplicationRequest.req_types[:page_view_anon],
        }
      else
        {
          logged_in: ApplicationRequest.req_types[:page_view_logged_in_browser],
          anonymous: ApplicationRequest.req_types[:page_view_anon_browser],
        }
      end.merge(
        crawlers: ApplicationRequest.req_types[:page_view_crawler],
        embedded: ApplicationRequest.req_types[:page_view_embed],
      )
  end

  def traffic_rows(range_start_date, range_end_date)
    DB.query(
      <<~SQL,
        WITH buckets AS (
          SELECT
            bucket_start::date AS date,
            LEAST(
              (
                bucket_start::date + CAST(:bucket_interval AS interval) - INTERVAL '1 day'
              )::date,
              CAST(:end_date AS date)
            ) AS end_date
          FROM generate_series(
            CAST(:start_date AS date),
            CAST(:end_date AS date),
            CAST(:bucket_interval AS interval)
          ) bucket_start
        )
        SELECT
          buckets.date,
          buckets.end_date,
          COALESCE(SUM(CASE WHEN ar.req_type = :logged_in_req_type THEN ar.count ELSE 0 END), 0)::bigint AS logged_in,
          COALESCE(SUM(CASE WHEN ar.req_type = :anonymous_req_type THEN ar.count ELSE 0 END), 0)::bigint AS anonymous,
          COALESCE(SUM(CASE WHEN ar.req_type = :crawler_req_type THEN ar.count ELSE 0 END), 0)::bigint AS crawlers,
          COALESCE(SUM(CASE WHEN ar.req_type = :embedded_req_type THEN ar.count ELSE 0 END), 0)::bigint AS embedded
        FROM buckets
        LEFT JOIN application_requests ar
          ON ar.date BETWEEN buckets.date AND buckets.end_date
          AND ar.req_type IN (
            :logged_in_req_type,
            :anonymous_req_type,
            :crawler_req_type,
            :embedded_req_type
          )
        GROUP BY buckets.date, buckets.end_date
        ORDER BY buckets.date ASC
      SQL
      start_date: range_start_date,
      end_date: range_end_date,
      bucket_interval: bucket_interval,
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
    return false if login_required?
    return false if !embedding_enabled?
    return false if !EmbeddableHost.exists?

    true
  end

  def embedding_enabled?
    SiteSetting.embed_topics_list || SiteSetting.embed_full_app
  end

  def selected_day_count
    (end_date.to_date - start_date.to_date).to_i + 1
  end

  def bucket_interval
    return "1 day" if selected_day_count <= 31
    return "1 week" if selected_day_count < 365

    "1 month"
  end
end
