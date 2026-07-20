# frozen_string_literal: true

class BrowserTrafficExplorerQuery
  class InvalidParameter < StandardError
  end

  class Timeout < StandardError
  end

  EVENT_LIMIT = 1_000_000
  FACET_LIMIT = 8
  BROWSER_SQL = <<~SQL.squish
    CASE
      WHEN position('Edg' IN user_agent) > 0 THEN 'edge'
      WHEN position('Opera' IN user_agent) > 0 OR position('OPR' IN user_agent) > 0 THEN 'opera'
      WHEN position('Firefox' IN user_agent) > 0 THEN 'firefox'
      WHEN position('Chrome' IN user_agent) > 0 OR position('CriOS' IN user_agent) > 0 THEN 'chrome'
      WHEN position('Safari' IN user_agent) > 0 THEN 'safari'
      WHEN position('MSIE' IN user_agent) > 0 OR position('Trident' IN user_agent) > 0 THEN 'ie'
      WHEN position('Discourse' IN user_agent) > 0 THEN 'discoursehub'
      ELSE 'unknown'
    END
  SQL
  NORMALIZED_URL_SQL = <<~SQL.squish
    COALESCE(
      NULLIF(
        regexp_replace(
          CASE
            WHEN url ~* '^https?://' THEN
              regexp_replace(split_part(split_part(url, '?', 1), '#', 1), '^https?://[^/]+', '', 'i')
            ELSE split_part(split_part(url, '?', 1), '#', 1)
          END,
          '/+$',
          ''
        ),
        ''
      ),
      '/'
    )
  SQL
  private_constant :BROWSER_SQL, :NORMALIZED_URL_SQL

  FACETS = {
    "normalized_url" => {
      max_length: 2000,
    },
    "normalized_referrer" => {
      column: "normalized_referrer",
      max_length: 2000,
    },
    "country_code" => {
      column: "country_code",
      max_length: 2,
    },
    "asn" => {
      column: "asn",
    },
    "ip_address" => {
      column: "ip_address",
      max_length: 45,
    },
    "browser" => {
    },
  }.freeze

  def self.call(start_date:, end_date:, filters:, snapshot_event_id: nil)
    new(start_date:, end_date:, filters:, snapshot_event_id:).call
  end

  def initialize(start_date:, end_date:, filters:, snapshot_event_id:)
    @requested_start_date = parse_date(start_date)
    @requested_end_date = parse_date(end_date)
    @filters = validate_filters(filters)
    @snapshot_event_id = validate_snapshot_event_id(snapshot_event_id)
    validate_date_range
  end

  def call
    Discourse.cache.fetch(result_cache_key, expires_in: 1.minute) { query }
  rescue ActiveRecord::StatementInvalid => error
    raise Timeout if error.cause.is_a?(PG::QueryCanceled)

    raise
  end

  private

  attr_reader :requested_start_date, :requested_end_date, :filters

  def parse_date(value)
    date = Date.iso8601(value.to_s)
    raise InvalidParameter unless value.to_s == date.iso8601

    date
  rescue Date::Error
    raise InvalidParameter
  end

  def validate_date_range
    raise InvalidParameter if requested_start_date > requested_end_date
    if requested_end_date < earliest_date || requested_start_date > latest_date
      raise InvalidParameter
    end
  end

  def validate_snapshot_event_id(value)
    return nil if value.blank?

    snapshot_event_id = Integer(value.to_s, 10)
    raise InvalidParameter unless snapshot_event_id.positive?

    snapshot_event_id
  rescue ArgumentError, TypeError
    raise InvalidParameter
  end

  def validate_filters(raw_filters)
    raise InvalidParameter unless raw_filters.is_a?(Hash)

    raw_filters
      .to_h
      .each_with_object({}) do |(key, value), validated|
        facet = FACETS[key.to_s]
        raise InvalidParameter unless facet

        validated[key.to_s] = validate_filter_value(key.to_s, value, facet)
      end
  end

  def validate_filter_value(key, value, facet)
    return nil if value.nil?

    case key
    when "asn"
      raise InvalidParameter unless value.is_a?(Integer) && value.positive?
    when "ip_address"
      raise InvalidParameter unless value.is_a?(String) && !value.include?("/")

      IPAddr.new(value)
    when "country_code"
      raise InvalidParameter unless value.is_a?(String) && value.match?(/\A[A-Z]{2}\z/)
    when "normalized_url"
      raise InvalidParameter unless value.is_a?(String) && value.start_with?("/")
    when "browser"
      if %w[chrome discoursehub edge firefox ie opera safari unknown].exclude?(value)
        raise InvalidParameter
      end
    else
      raise InvalidParameter unless value.is_a?(String) && value.present?
    end

    raise InvalidParameter if facet[:max_length] && value.length > facet[:max_length]

    value
  rescue IPAddr::Error
    raise InvalidParameter
  end

  def earliest_date
    @earliest_date ||= BrowserPageviewEvent.retention_cutoff.to_date
  end

  def latest_date
    @latest_date ||= Date.current
  end

  def effective_start_date
    @effective_start_date ||= [requested_start_date, earliest_date].max
  end

  def effective_end_date
    @effective_end_date ||= [requested_end_date, latest_date].min
  end

  def snapshot_event_id
    @snapshot_event_id ||= date_scope.maximum(:id) || 0
  end

  def date_scope
    BrowserPageviewEvent.where(source: BrowserPageviewEvent.rollup_source).where(
      created_at: effective_start_date.in_time_zone...effective_end_date.next_day.in_time_zone,
    )
  end

  def capped_scope
    date_scope
      .where("id <= ?", snapshot_event_id)
      .order(created_at: :desc, id: :desc)
      .limit(EVENT_LIMIT)
  end

  def analysis_scope
    BrowserPageviewEvent.from(capped_scope, :browser_pageview_events)
  end

  def filtered_scope
    filters.reduce(analysis_scope) do |scope, (facet, value)|
      case facet
      when "browser"
        scope.where("#{BROWSER_SQL} = ?", value)
      when "normalized_url"
        scope.where("#{NORMALIZED_URL_SQL} = :normalized_url", normalized_url: value)
      else
        scope.where(FACETS.fetch(facet)[:column] => value)
      end
    end
  end

  def query
    BrowserPageviewEvent.transaction(requires_new: true) do
      BrowserPageviewEvent.connection.execute("SET TRANSACTION READ ONLY")
      BrowserPageviewEvent.connection.execute("SET LOCAL statement_timeout = '10s'")

      scope = filtered_scope
      rows = dimension_rows(scope)
      session_summary = session_summary_for(scope)

      {
        start_date: effective_start_date.iso8601,
        end_date: effective_end_date.iso8601,
        requested_start_date: requested_start_date.iso8601,
        requested_end_date: requested_end_date.iso8601,
        snapshot_event_id:,
        filters:,
        analysis: analysis_metadata,
        summary: summary_for(rows, session_summary),
        pageview_series: pageview_series_for(rows),
        facets: facets_for(rows),
      }
    end
  end

  def analysis_metadata
    Discourse
      .cache
      .fetch(analysis_cache_key, expires_in: 5.minutes) do
        analyzed_events = analysis_scope.pick(Arel.sql("COUNT(*)"))

        {
          event_limit: EVENT_LIMIT,
          analyzed_events: analyzed_events.to_i,
          truncated:
            date_scope.where("id <= ?", snapshot_event_id).limit(EVENT_LIMIT + 1).count >
              EVENT_LIMIT,
        }
      end
  end

  def result_cache_key
    identity = {
      version: 4,
      start_date: effective_start_date,
      end_date: effective_end_date,
      source: BrowserPageviewEvent.rollup_source,
      snapshot_event_id:,
      event_limit: EVENT_LIMIT,
      filters: filters.sort.to_h,
    }
    "browser-traffic-result:#{Digest::SHA256.hexdigest(JSON.generate(identity))}"
  end

  def analysis_cache_key
    identity = {
      version: 2,
      start_date: effective_start_date,
      end_date: effective_end_date,
      source: BrowserPageviewEvent.rollup_source,
      snapshot_event_id:,
      event_limit: EVENT_LIMIT,
    }
    "browser-traffic-analysis:#{Digest::SHA256.hexdigest(JSON.generate(identity))}"
  end

  def dimension_rows(scope)
    DB.query(<<~SQL, facet_limit: FACET_LIMIT)
      WITH filtered_events AS (
        #{
        scope.select(
          :created_at,
          :url,
          :normalized_referrer,
          :country_code,
          :asn,
          :ip_address,
          :user_agent,
          :user_id,
          :session_id,
        ).to_sql
      }
      ),
      grouped AS (
        SELECT
          CASE
            WHEN GROUPING(date_trunc('day', created_at)) = 0 THEN 'date'
            WHEN GROUPING(#{NORMALIZED_URL_SQL}) = 0 THEN 'normalized_url'
            WHEN GROUPING(normalized_referrer) = 0 THEN 'normalized_referrer'
            WHEN GROUPING(country_code) = 0 THEN 'country_code'
            WHEN GROUPING(asn) = 0 THEN 'asn'
            WHEN GROUPING(ip_address) = 0 THEN 'ip_address'
            ELSE 'browser'
          END AS dimension,
          CASE
            WHEN GROUPING(date_trunc('day', created_at)) = 0
              THEN to_char(date_trunc('day', created_at), 'YYYY-MM-DD')
            WHEN GROUPING(#{NORMALIZED_URL_SQL}) = 0 THEN #{NORMALIZED_URL_SQL}
            WHEN GROUPING(normalized_referrer) = 0 THEN normalized_referrer::text
            WHEN GROUPING(country_code) = 0 THEN country_code::text
            WHEN GROUPING(asn) = 0 THEN asn::text
            WHEN GROUPING(ip_address) = 0 THEN host(ip_address)
            ELSE #{BROWSER_SQL}
          END AS value,
          COUNT(*) AS pageviews,
          MIN(host(ip_address)) AS representative_ip,
          COUNT(*) FILTER (WHERE user_id IS NOT NULL) AS logged_in_pageviews,
          COUNT(*) FILTER (WHERE user_id IS NULL) AS anonymous_pageviews
        FROM filtered_events
        GROUP BY GROUPING SETS (
          (date_trunc('day', created_at)),
          (#{NORMALIZED_URL_SQL}),
          (normalized_referrer),
          (country_code),
          (asn),
          (ip_address),
          (#{BROWSER_SQL})
        )
      ),
      ranked AS (
        SELECT
          grouped.*,
          ROW_NUMBER() OVER (
            PARTITION BY dimension
            ORDER BY pageviews DESC, value ASC NULLS LAST
          ) AS facet_rank
        FROM grouped
      )
      SELECT dimension, value, pageviews, representative_ip, logged_in_pageviews, anonymous_pageviews
      FROM ranked
      WHERE dimension = 'date' OR facet_rank <= :facet_limit
      ORDER BY dimension, facet_rank
    SQL
  end

  def session_summary_for(scope)
    row = DB.query(<<~SQL, completed_before: 10.minutes.ago).first
        WITH filtered_events AS (
          #{scope.select(:session_id, :created_at).to_sql}
        ),
        sessions AS (
          SELECT
            session_id,
            COUNT(*) AS pageviews,
            MIN(created_at) AS first_event_at
          FROM filtered_events
          GROUP BY session_id
        )
        SELECT
          COUNT(*) AS sessions,
          COUNT(*) FILTER (WHERE first_event_at < :completed_before) AS completed_sessions,
          COUNT(*) FILTER (
            WHERE first_event_at < :completed_before
              AND pageviews = 1
              AND COALESCE(engagement.engaged_seconds, 0) < 10
          ) AS bounced,
          COALESCE(SUM(engagement.engaged_seconds) FILTER (
            WHERE first_event_at < :completed_before
          ), 0) AS engaged_seconds_total
        FROM sessions
        LEFT JOIN browser_pageview_session_engagements engagement
          ON engagement.session_id = sessions.session_id
      SQL

    {
      sessions: row.sessions.to_i,
      completed_sessions: row.completed_sessions.to_i,
      bounced: row.bounced.to_i,
      engaged_seconds_total: row.engaged_seconds_total.to_i,
    }
  end

  def summary_for(rows, session_summary)
    date_rows = rows.select { |row| row.dimension == "date" }
    pageviews = date_rows.sum { |row| row.pageviews.to_i }
    logged_in_pageviews = date_rows.sum { |row| row.logged_in_pageviews.to_i }
    anonymous_pageviews = date_rows.sum { |row| row.anonymous_pageviews.to_i }
    completed_sessions = session_summary[:completed_sessions]

    {
      pageviews:,
      sessions: session_summary[:sessions],
      logged_in_pageviews:,
      anonymous_pageviews:,
      bounce_rate:
        (
          if completed_sessions.zero?
            nil
          else
            ((session_summary[:bounced].to_f / completed_sessions) * 100).round
          end
        ),
      average_session_duration_seconds:
        (
          if completed_sessions.zero?
            nil
          else
            (session_summary[:engaged_seconds_total].to_f / completed_sessions).round
          end
        ),
    }
  end

  def pageview_series_for(rows)
    date_rows = rows.select { |row| row.dimension == "date" }.sort_by(&:value)

    [
      {
        req: "page_view_logged_in_browser",
        label: I18n.t("reports.site_traffic.xaxis.page_view_logged_in_browser"),
        color: Reports::SiteTraffic::SERIES_COLORS.fetch("page_view_logged_in_browser"),
        data: date_rows.map { |row| { x: row.value, y: row.logged_in_pageviews.to_i } },
      },
      {
        req: "page_view_anon_browser",
        label: I18n.t("reports.site_traffic.xaxis.page_view_anon_browser"),
        color: Reports::SiteTraffic::SERIES_COLORS.fetch("page_view_anon_browser"),
        data: date_rows.map { |row| { x: row.value, y: row.anonymous_pageviews.to_i } },
      },
    ]
  end

  def asn_name(row)
    return if row.value.nil? || row.representative_ip.nil?

    DiscourseIpInfo.get(row.representative_ip)[:organization]
  end

  def facets_for(rows)
    FACETS.keys.index_with do |facet|
      rows
        .select { |row| row.dimension == facet }
        .map do |row|
          {
            value: facet == "asn" && row.value ? row.value.to_i : row.value,
            name: facet == "asn" ? asn_name(row) : nil,
            pageviews: row.pageviews.to_i,
            logged_in_pageviews: row.logged_in_pageviews.to_i,
            anonymous_pageviews: row.anonymous_pageviews.to_i,
          }
        end
    end
  end
end
