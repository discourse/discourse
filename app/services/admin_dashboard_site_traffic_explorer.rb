# frozen_string_literal: true

class AdminDashboardSiteTrafficExplorer
  include Service::Base

  DIMENSION_LIMIT = 50
  private_constant :DIMENSION_LIMIT

  STATEMENT_TIMEOUT_MS = 10_000
  private_constant :STATEMENT_TIMEOUT_MS

  FILTER_KEYS = %i[traffic_type top_url entry_url referrer country network browser ip].freeze
  private_constant :FILTER_KEYS

  FILTER_DIMENSIONS = {
    top_url: "top_urls",
    entry_url: "entry_urls",
    referrer: "referrers",
    country: "countries",
    network: "networks",
    browser: "browsers",
    ip: "ip_addresses",
  }.freeze
  private_constant :FILTER_DIMENSIONS

  BROWSER_VALUES = %w[edge firefox chrome safari unknown].freeze
  private_constant :BROWSER_VALUES

  TRAFFIC_TYPE_VALUES = %w[logged_in anonymous likely_crawler].freeze
  private_constant :TRAFFIC_TYPE_VALUES

  params do
    attribute :start_date, :date
    attribute :end_date, :date
    attribute :traffic_type, :string
    attribute :top_url, :string
    attribute :entry_url, :string
    attribute :referrer, :string
    attribute :country, :string
    attribute :network, :string
    attribute :browser, :string
    attribute :ip, :string

    validates :start_date, :end_date, presence: true
    validate :start_date_precedes_end_date

    def filters
      FILTER_KEYS.to_h { |key| [key, normalize_filter(key, public_send(key))] }
    end

    private

    def start_date_precedes_end_date
      return if start_date.blank? || end_date.blank? || start_date <= end_date

      errors.add(:start_date, :invalid)
    end

    def normalize_filter(key, value)
      return nil if value.nil?
      return "" if key == :referrer && value == ""
      raise Discourse::InvalidParameters.new(key) if value.blank?

      case key
      when :traffic_type
        traffic_types = value.to_s.split(",").uniq
        if traffic_types.empty? || (traffic_types - TRAFFIC_TYPE_VALUES).any?
          raise Discourse::InvalidParameters.new(key)
        end
        TRAFFIC_TYPE_VALUES.select { |traffic_type| traffic_types.include?(traffic_type) }
      when :top_url, :entry_url
        BrowserPageviewEventUrlNormalizer.normalize_site_path(value) ||
          raise(Discourse::InvalidParameters.new(key))
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
        BrowserPageviewEventUrlNormalizer.normalize_referrer("https://#{value}").presence ||
          raise(Discourse::InvalidParameters.new(key))
      end
    rescue IPAddr::Error
      raise Discourse::InvalidParameters.new(key)
    end
  end

  step :load_traffic

  private

  def load_traffic(params:)
    filters = params.filters
    row = execute_query(start_date: params.start_date, end_date: params.end_date, filters:)

    traffic = {
      partial_data: partial_data(row.fetch("pageview_limited"), start_date: params.start_date),
      summary: row.fetch("summary"),
      series: row.fetch("series"),
      series_colors: series_colors,
      dimensions: decorate_dimensions(row.fetch("dimensions")),
    }
    active_filters =
      decorate_active_filters(row.fetch("active_filter_representative_ips"), filters:)
    traffic[:active_filters] = active_filters if active_filters.any?
    context[:traffic] = traffic
  rescue ActiveRecord::QueryCanceled, PG::QueryCanceled
    fail!("traffic_query_timeout")
  end

  def execute_query(start_date:, end_date:, filters:)
    parameters = query_params(start_date:, end_date:, filters:)

    ActiveRecord::Base.transaction(requires_new: true) do
      DB.exec("SET LOCAL statement_timeout = #{STATEMENT_TIMEOUT_MS}")
      DB.query_hash(
        query(start_date: parameters[:start_date], end_date: parameters[:end_date]),
        parameters,
      ).first
    end
  end

  def query_params(start_date:, end_date:, filters:)
    retention_cutoff = BrowserPageviewEvent.retention_cutoff.to_date
    effective_start_date = [start_date, retention_cutoff].max
    cap = SiteSetting.admin_site_traffic_event_cap

    {
      start_date: effective_start_date,
      end_date: end_date + 1.day,
      cap: cap,
      site_host: BrowserPageviewEventUrlNormalizer.normalize_host(Discourse.current_hostname),
      top_url: filters[:top_url],
      entry_url: filters[:entry_url],
      referrer: filters[:referrer],
      country: filters[:country],
      network_asn: filters[:network],
      browser: filters[:browser],
      ip_address: filters[:ip],
      traffic_type_filtered: filters[:traffic_type].present?,
      include_logged_in: filters[:traffic_type]&.include?("logged_in"),
      include_anonymous: filters[:traffic_type]&.include?("anonymous"),
      include_likely_crawler: filters[:traffic_type]&.include?("likely_crawler"),
      crawler_detection_enabled: UpcomingChanges.enabled?(:improved_crawler_detection),
      crawler_threshold: CrawlerScorer::BOT_SCORE_THRESHOLD,
      bounce_threshold:
        BrowserPageviewSessionEngagementDailyRollup.bounce_engaged_seconds_threshold,
      dimension_limit: DIMENSION_LIMIT,
    }
  end

  def query(start_date:, end_date:)
    source_condition =
      BrowserPageviewEvent.rollup_source_condition(table: "bpe", start_date:, end_date:)

    <<~SQL
      WITH population AS MATERIALIZED (
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
          AND #{source_condition}
        ORDER BY bpe.created_at DESC, bpe.id DESC
        LIMIT :cap
      ),
      population_stats AS MATERIALIZED (
        SELECT
          COUNT(*) AS row_count,
          MIN(created_at) AS oldest_created_at
        FROM population
      ),
      population_boundary AS MATERIALIZED (
        SELECT
          population_stats.row_count,
          population_stats.oldest_created_at,
          MIN(population.id) AS oldest_id
        FROM population_stats
        LEFT JOIN population
          ON population.created_at = population_stats.oldest_created_at
        GROUP BY
          population_stats.row_count,
          population_stats.oldest_created_at
      ),
      browser_values AS MATERIALIZED (
        SELECT
          user_agent,
          CASE
            WHEN user_agent ~* 'Edg' THEN 'edge'
            WHEN user_agent ~* '(Opera|OPR)' THEN 'unknown'
            WHEN user_agent ~* 'Firefox' THEN 'firefox'
            WHEN user_agent ~* '(Chrome|CriOS)' THEN 'chrome'
            WHEN user_agent ~* 'Safari' THEN 'safari'
            ELSE 'unknown'
          END AS browser
        FROM population
        GROUP BY user_agent
      ),
      classified AS (
        SELECT
          population.created_at,
          population.session_id,
          population.user_id,
          population.normalized_url,
          population.normalized_referrer,
          population.country_code,
          population.asn,
          population.ip_address,
          browser_values.browser,
          (
            population.normalized_referrer IS NULL
            OR split_part(
              split_part(population.normalized_referrer, '/', 1),
              '?',
              1
            ) <> :site_host
          ) AS acquisition_entry,
          (
            :crawler_detection_enabled
            AND COALESCE(population.score, 0) > :crawler_threshold
          ) AS likely_crawler
        FROM population
        JOIN browser_values
          ON browser_values.user_agent = population.user_agent
      ),
      dimensioned AS (
        SELECT
          classified.created_at,
          classified.session_id,
          classified.user_id,
          classified.normalized_url,
          classified.country_code,
          classified.asn,
          classified.ip_address,
          classified.browser,
          classified.likely_crawler,
          CASE
            WHEN classified.acquisition_entry THEN classified.normalized_url
          END AS entry_url,
          CASE
            WHEN classified.acquisition_entry
              THEN COALESCE(classified.normalized_referrer, '')
          END AS referrer
        FROM classified
      ),
      filtered AS MATERIALIZED (
        SELECT *
        FROM dimensioned
        WHERE (:top_url IS NULL OR normalized_url = :top_url)
          AND (
            :entry_url IS NULL
            OR entry_url = :entry_url
          )
          AND (
            :referrer IS NULL
            OR referrer = :referrer
          )
          AND (:country IS NULL OR country_code = :country)
          AND (:network_asn IS NULL OR asn = :network_asn)
          AND (:browser IS NULL OR browser = :browser)
          AND (:ip_address IS NULL OR host(ip_address) = :ip_address)
          AND (
            NOT :traffic_type_filtered
            OR (
              :include_logged_in
              AND NOT likely_crawler
              AND user_id IS NOT NULL
            )
            OR (
              :include_anonymous
              AND NOT likely_crawler
              AND user_id IS NULL
            )
            OR (
              :include_likely_crawler
              AND likely_crawler
            )
          )
      ),
      sessions AS (
        SELECT session_id, COUNT(*) AS pageviews
        FROM filtered
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
      series_rows AS (
        SELECT
          created_at::date AS date,
          COUNT(*)::integer AS pageviews,
          COUNT(*) FILTER (
            WHERE NOT likely_crawler AND user_id IS NOT NULL
          )::integer AS logged_in_human_pageviews,
          COUNT(*) FILTER (
            WHERE NOT likely_crawler AND user_id IS NULL
          )::integer AS anonymous_human_pageviews,
          COUNT(*) FILTER (WHERE likely_crawler)::integer AS likely_crawler_pageviews
        FROM filtered
        GROUP BY created_at::date
      ),
      traffic_summary AS (
        SELECT
          COALESCE(SUM(pageviews), 0)::integer AS pageviews,
          COALESCE(SUM(logged_in_human_pageviews), 0)::integer AS logged_in_pageviews
        FROM series_rows
      ),
      bounded_dimension_rows AS MATERIALIZED (
        SELECT
          CASE
            WHEN GROUPING(country_code) = 0 THEN 'countries'
            WHEN GROUPING(browser) = 0 THEN 'browsers'
          END AS dimension,
          country_code,
          browser,
          COUNT(*)::integer AS pageviews,
          MIN(ip_address) AS representative_ip
        FROM filtered
        GROUP BY GROUPING SETS ((country_code), (browser))
      )
      SELECT
        (
          SELECT
            population_boundary.row_count = :cap
            AND EXISTS (
              SELECT 1
              FROM browser_pageview_events bpe
              WHERE bpe.created_at >= :start_date
                AND bpe.created_at < :end_date
                AND #{source_condition}
                AND (bpe.created_at, bpe.id) < (
                  population_boundary.oldest_created_at,
                  population_boundary.oldest_id
                )
              LIMIT 1
            )
          FROM population_boundary
        ) AS pageview_limited,
        jsonb_build_object(
          'country', (
            SELECT host(MIN(ip_address))
            FROM population
            WHERE :country IS NOT NULL
              AND country_code = :country
          ),
          'network', (
            SELECT host(MIN(ip_address))
            FROM population
            WHERE :network_asn IS NOT NULL
              AND asn = :network_asn
          )
        ) AS active_filter_representative_ips,
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
                pageviews,
                host(representative_ip) AS representative_ip
              FROM bounded_dimension_rows
              WHERE dimension = 'countries'
                AND country_code IS NOT NULL
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
                host(MIN(ip_address)) AS representative_ip
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
              SELECT browser AS value, pageviews
              FROM bounded_dimension_rows
              WHERE dimension = 'browsers'
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

  def partial_data(pageview_limited, start_date:)
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

  def decorate_active_filters(representative_ips, filters:)
    filters.flat_map do |key, value|
      next [] if value.nil?

      if key == :traffic_type
        next(
          value.map do |traffic_type|
            {
              key: key,
              value: traffic_type,
              label: I18n.t("admin_site_traffic_explorer.traffic_types.#{traffic_type}"),
            }
          end
        )
      end

      canonical_value = key == :network ? "AS#{value}" : value
      dimension = FILTER_DIMENSIONS.fetch(key)
      [
        {
          key: key,
          value: canonical_value,
          label: dimension_label(dimension, canonical_value, representative_ips[key.to_s]),
        },
      ]
    end
  end

  def series_colors
    {
      "logged_in_human_pageviews" =>
        Reports::SiteTraffic::SERIES_COLORS.fetch("page_view_logged_in_browser"),
      "anonymous_human_pageviews" =>
        Reports::SiteTraffic::SERIES_COLORS.fetch("page_view_anon_browser"),
      "likely_crawler_pageviews" =>
        Reports::SiteTraffic::SERIES_COLORS.fetch("page_view_likely_crawler"),
    }
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
    return value if representative_ip.blank?

    info = DiscourseIpInfo.get(representative_ip, locale: I18n.locale, resolve_hostname: false)
    return info[:country] if info[:country_code].to_s.casecmp?(value) && info[:country].present?

    value
  end

  def network_label(value, representative_ip)
    return value if representative_ip.blank?

    info = DiscourseIpInfo.get(representative_ip, locale: I18n.locale, resolve_hostname: false)
    asn = value.delete_prefix("AS").to_i
    return value if info[:asn].to_i != asn || info[:organization].blank?

    "#{info[:organization]} (#{value})"
  end
end
