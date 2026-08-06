# frozen_string_literal: true

class AdminDashboardSiteTrafficExplorer
  BROWSER_CLASSIFIER_VERSION = 1
  DIMENSION_LIMIT = 50
  STATEMENT_TIMEOUT_MS = 10_000
  FILTER_KEYS = %i[top_url entry_url referrer country network browser ip].freeze
  BROWSER_VALUES = %w[edge opera firefox chrome safari ie discoursehub unknown].freeze
  private_constant :BROWSER_CLASSIFIER_VERSION
  private_constant :DIMENSION_LIMIT
  private_constant :STATEMENT_TIMEOUT_MS
  private_constant :FILTER_KEYS
  private_constant :BROWSER_VALUES

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @params = params.with_indifferent_access
    @start_date = parse_date(:start_date)
    @end_date = parse_date(:end_date)
    raise Discourse::InvalidParameters.new(:start_date) if @start_date > @end_date

    @filters = normalize_filters
  end

  def call
    row = execute_query

    {
      partial_data: partial_data(row.fetch("pageview_limited")),
      summary: row.fetch("summary"),
      series: row.fetch("series"),
      dimensions: decorate_dimensions(row.fetch("dimensions")),
    }
  end

  private

  attr_reader :start_date, :end_date, :filters

  def parse_date(key)
    Date.iso8601(@params.fetch(key))
  rescue Date::Error, KeyError, TypeError
    raise Discourse::InvalidParameters.new(key)
  end

  def normalize_filters
    FILTER_KEYS.to_h { |key| [key, normalize_filter(key, @params[key])] }
  end

  def normalize_filter(key, value)
    return nil if value.nil?
    return "" if key == :referrer && value == ""
    raise Discourse::InvalidParameters.new(key) if value.blank?

    case key
    when :top_url, :entry_url
      BrowserPageviewUrlInspector.normalize(value) || raise(Discourse::InvalidParameters.new(key))
    when :country
      country = value.to_s.upcase
      raise Discourse::InvalidParameters.new(key) if !country.match?(/\A[A-Z]{2}\z/)
      country
    when :network
      match = value.to_s.match(/\AAS(\d+)\z/)
      raise Discourse::InvalidParameters.new(key) if !match
      match[1].to_i
    when :browser
      browser = value.to_s
      raise Discourse::InvalidParameters.new(key) if !BROWSER_VALUES.include?(browser)
      browser
    when :ip
      IPAddr.new(value.to_s).to_s
    when :referrer
      BrowserPageviewReferrerInspector.normalize("https://#{value}")&.split("/", 2)&.first ||
        raise(Discourse::InvalidParameters.new(key))
    end
  rescue IPAddr::Error
    raise Discourse::InvalidParameters.new(key)
  end

  def execute_query
    ActiveRecord::Base.transaction(requires_new: true) do
      DB.exec("SET TRANSACTION READ ONLY")
      DB.exec("SET LOCAL statement_timeout = #{STATEMENT_TIMEOUT_MS}")
      DB.query_hash(query, query_params).first
    end
  end

  def query_params
    retention_cutoff = BrowserPageviewEvent.retention_cutoff.to_date
    effective_start_date = [start_date, retention_cutoff].max
    cap = SiteSetting.admin_site_traffic_event_cap

    {
      start_date: effective_start_date,
      end_date: end_date + 1.day,
      cap: cap,
      cap_plus_one: cap + 1,
      top_url: filters[:top_url],
      entry_url: filters[:entry_url],
      referrer: filters[:referrer],
      country: filters[:country],
      network_asn: filters[:network],
      browser: filters[:browser],
      ip_address: filters[:ip],
      current_hostname: BrowserPageviewReferrerInspector.normalize_host(Discourse.current_hostname),
      crawler_detection_enabled: UpcomingChanges.enabled?(:improved_crawler_detection),
      crawler_threshold: CrawlerScorer::BOT_SCORE_THRESHOLD,
      bounce_threshold:
        BrowserPageviewSessionEngagementDailyRollup.bounce_engaged_seconds_threshold,
      dimension_limit: DIMENSION_LIMIT,
    }
  end

  def query
    <<~SQL
      WITH eligible AS MATERIALIZED (
        SELECT
          bpe.id,
          bpe.created_at,
          bpe.session_id,
          bpe.user_id,
          bpe.normalized_url,
          bpe.normalized_referrer,
          bpe.country_code,
          bpe.asn,
          bpe.ip_address,
          bpe.user_agent,
          bpe.score
        FROM browser_pageview_events bpe
        WHERE bpe.created_at >= :start_date
          AND bpe.created_at < :end_date
          AND #{BrowserPageviewEvent.rollup_source_condition(table: "bpe")}
        ORDER BY bpe.created_at DESC, bpe.id DESC
        LIMIT :cap_plus_one
      ),
      population AS MATERIALIZED (
        SELECT *
        FROM eligible
        ORDER BY created_at DESC, id DESC
        LIMIT :cap
      ),
      classified AS MATERIALIZED (
        SELECT
          population.*,
          ROW_NUMBER() OVER (
            PARTITION BY session_id
            ORDER BY created_at, id
          ) AS session_position,
          CASE
            WHEN user_agent ~* 'Edg' THEN 'edge'
            WHEN user_agent ~* '(Opera|OPR)' THEN 'opera'
            WHEN user_agent ~* 'Firefox' THEN 'firefox'
            WHEN user_agent ~* '(Chrome|CriOS)' THEN 'chrome'
            WHEN user_agent ~* 'Safari' THEN 'safari'
            WHEN user_agent ~* '(MSIE|Trident)' THEN 'ie'
            WHEN user_agent ~* 'Discourse' THEN 'discoursehub'
            ELSE 'unknown'
          END AS browser,
          (
            :crawler_detection_enabled
            AND COALESCE(score, 0) > :crawler_threshold
          ) AS likely_crawler
        FROM population
      ),
      dimensioned AS MATERIALIZED (
        SELECT
          classified.*,
          CASE WHEN session_position = 1 THEN normalized_url END AS entry_url,
          CASE
            WHEN session_position <> 1 THEN NULL
            WHEN normalized_referrer IS NULL THEN ''
            WHEN split_part(normalized_referrer, '/', 1) = :current_hostname THEN ''
            ELSE split_part(normalized_referrer, '/', 1)
          END AS referrer
        FROM classified
      ),
      filtered AS MATERIALIZED (
        SELECT *
        FROM dimensioned
        WHERE (:top_url IS NULL OR normalized_url = :top_url)
          AND (
            :entry_url IS NULL
            OR (session_position = 1 AND entry_url = :entry_url)
          )
          AND (
            :referrer IS NULL
            OR (session_position = 1 AND referrer = :referrer)
          )
          AND (:country IS NULL OR country_code = :country)
          AND (:network_asn IS NULL OR asn = :network_asn)
          AND (:browser IS NULL OR browser = :browser)
          AND (:ip_address IS NULL OR host(ip_address) = :ip_address)
      ),
      sessions AS MATERIALIZED (
        SELECT session_id, COUNT(*) AS pageviews
        FROM population
        GROUP BY session_id
      ),
      session_summary AS (
        SELECT
          COUNT(*)::integer AS distinct_sessions,
          COUNT(*) FILTER (
            WHERE sessions.pageviews = 1
              AND COALESCE(engagement.engaged_seconds, 0) < :bounce_threshold
          )::integer AS bounced_sessions,
          COALESCE(SUM(engagement.engaged_seconds), 0)::bigint AS engaged_seconds
        FROM sessions
        LEFT JOIN browser_pageview_session_engagements engagement
          ON engagement.session_id = sessions.session_id
      ),
      traffic_summary AS (
        SELECT
          COUNT(*) FILTER (WHERE NOT likely_crawler)::integer AS pageviews,
          COUNT(*) FILTER (
            WHERE NOT likely_crawler AND user_id IS NOT NULL
          )::integer AS logged_in_pageviews
        FROM filtered
      ),
      series_rows AS (
        SELECT
          created_at::date AS date,
          COUNT(*) FILTER (WHERE NOT likely_crawler)::integer AS pageviews,
          COUNT(*) FILTER (
            WHERE NOT likely_crawler AND user_id IS NOT NULL
          )::integer AS logged_in_human_pageviews,
          COUNT(*) FILTER (
            WHERE NOT likely_crawler AND user_id IS NULL
          )::integer AS anonymous_human_pageviews,
          COUNT(*) FILTER (WHERE likely_crawler)::integer AS likely_crawler_pageviews
        FROM filtered
        GROUP BY created_at::date
      )
      SELECT
        #{BROWSER_CLASSIFIER_VERSION} AS browser_classifier_version,
        (SELECT COUNT(*) > :cap FROM eligible) AS pageview_limited,
        jsonb_build_object(
          'pageviews', traffic_summary.pageviews,
          'distinct_sessions', session_summary.distinct_sessions,
          'logged_in_share', CASE
            WHEN traffic_summary.pageviews = 0 THEN 0
            ELSE ROUND(
              traffic_summary.logged_in_pageviews::numeric * 100 /
                traffic_summary.pageviews
            )::integer
          END,
          'bounce_rate', CASE
            WHEN session_summary.distinct_sessions = 0 THEN 0
            ELSE ROUND(
              session_summary.bounced_sessions::numeric * 100 /
                session_summary.distinct_sessions
            )::integer
          END,
          'average_session_duration_seconds', CASE
            WHEN session_summary.distinct_sessions = 0 THEN 0
            ELSE ROUND(
              session_summary.engaged_seconds::numeric /
                session_summary.distinct_sessions
            )::integer
          END
        ) AS summary,
        COALESCE(
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'date', date,
                'pageviews', pageviews,
                'logged_in_human_pageviews', logged_in_human_pageviews,
                'anonymous_human_pageviews', anonymous_human_pageviews,
                'likely_crawler_pageviews', likely_crawler_pageviews
              )
              ORDER BY date
            )
            FROM series_rows
          ),
          '[]'::jsonb
        ) AS series,
        jsonb_build_object(
          'top_urls', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object('value', value, 'pageviews', pageviews)
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT normalized_url AS value, COUNT(*)::integer AS pageviews
              FROM filtered
              WHERE normalized_url IS NOT NULL
              GROUP BY normalized_url
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          ),
          'entry_urls', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object('value', value, 'pageviews', pageviews)
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT entry_url AS value, COUNT(*)::integer AS pageviews
              FROM filtered
              WHERE entry_url IS NOT NULL
              GROUP BY entry_url
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          ),
          'referrers', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object('value', value, 'pageviews', pageviews)
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT referrer AS value, COUNT(*)::integer AS pageviews
              FROM filtered
              WHERE referrer IS NOT NULL
              GROUP BY referrer
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          ),
          'countries', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object(
                  'value', value,
                  'pageviews', pageviews,
                  'representative_ip', representative_ip
                )
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT
                country_code AS value,
                COUNT(*)::integer AS pageviews,
                MIN(host(ip_address)) AS representative_ip
              FROM filtered
              WHERE country_code IS NOT NULL
              GROUP BY country_code
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          ),
          'networks', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object(
                  'value', value,
                  'pageviews', pageviews,
                  'representative_ip', representative_ip
                )
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT
                'AS' || asn AS value,
                COUNT(*)::integer AS pageviews,
                MIN(host(ip_address)) AS representative_ip
              FROM filtered
              WHERE asn IS NOT NULL
              GROUP BY asn
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          ),
          'browsers', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object('value', value, 'pageviews', pageviews)
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT browser AS value, COUNT(*)::integer AS pageviews
              FROM filtered
              GROUP BY browser
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          ),
          'ip_addresses', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object('value', value, 'pageviews', pageviews)
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT host(ip_address) AS value, COUNT(*)::integer AS pageviews
              FROM filtered
              GROUP BY ip_address
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          )
        ) AS dimensions
      FROM traffic_summary
      CROSS JOIN session_summary
    SQL
  end

  def partial_data(pageview_limited)
    retention_limited = start_date < BrowserPageviewEvent.retention_cutoff.to_date
    return nil if !retention_limited && !pageview_limited

    if retention_limited && pageview_limited
      {
        reason: "retention_and_pageview_limit",
        available_start_date: BrowserPageviewEvent.retention_cutoff.to_date.iso8601,
        pageview_limit: SiteSetting.admin_site_traffic_event_cap,
      }
    elsif retention_limited
      {
        reason: "retention",
        available_start_date: BrowserPageviewEvent.retention_cutoff.to_date.iso8601,
      }
    else
      { reason: "pageview_limit", pageview_limit: SiteSetting.admin_site_traffic_event_cap }
    end
  end

  def decorate_dimensions(dimensions)
    dimensions.to_h do |dimension, rows|
      [dimension, rows.map { |row| decorate_dimension_row(dimension, row) }]
    end
  end

  def decorate_dimension_row(dimension, row)
    value = row.fetch("value")
    {
      value: value,
      label: dimension_label(dimension, value, row["representative_ip"]),
      pageviews: row.fetch("pageviews"),
    }
  end

  def dimension_label(dimension, value, representative_ip)
    case dimension
    when "referrers"
      value.presence || I18n.t("admin_site_traffic_explorer.direct_or_unknown")
    when "countries"
      country_label(value, representative_ip)
    when "networks"
      network_label(value, representative_ip)
    when "browsers"
      I18n.t("admin_site_traffic_explorer.browsers.#{value}", default: value)
    else
      value
    end
  end

  def country_label(value, representative_ip)
    info = DiscourseIpInfo.get(representative_ip, locale: I18n.locale, resolve_hostname: false)
    return info[:country] if info[:country_code].to_s.casecmp?(value) && info[:country].present?

    value
  end

  def network_label(value, representative_ip)
    info = DiscourseIpInfo.get(representative_ip, locale: I18n.locale, resolve_hostname: false)
    asn = value.delete_prefix("AS").to_i
    return value if info[:asn].to_i != asn || info[:organization].blank?

    "#{value} #{info[:organization]}"
  end
end
