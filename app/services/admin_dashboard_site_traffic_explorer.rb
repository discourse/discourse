# frozen_string_literal: true

class AdminDashboardSiteTrafficExplorer
  include Service::Base

  DIMENSION_LIMIT = 50
  private_constant :DIMENSION_LIMIT

  STATEMENT_TIMEOUT_MS = 10_000
  private_constant :STATEMENT_TIMEOUT_MS

  FILTER_KEYS = %i[
    traffic_type
    top_url
    entry_url
    referrer
    country
    network
    browser
    language
    ip
  ].freeze

  FILTER_DIMENSIONS = {
    top_url: "top_urls",
    entry_url: "entry_urls",
    referrer: "referrers",
    country: "countries",
    network: "networks",
    browser: "browsers",
    language: "languages",
    ip: "ip_addresses",
  }.freeze
  private_constant :FILTER_DIMENSIONS

  BROWSER_VALUES = BrowserPageviewEvent.browsers.keys.freeze
  private_constant :BROWSER_VALUES

  TRAFFIC_TYPE_VALUES = %w[logged_in anonymous likely_crawler].freeze
  private_constant :TRAFFIC_TYPE_VALUES

  params do
    attribute :start_date, :date
    attribute :end_date, :date
    attribute :traffic_type, :array
    attribute :top_url, :array
    attribute :entry_url, :array
    attribute :referrer, :array
    attribute :country, :array
    attribute :network, :array
    attribute :browser, :array
    attribute :language, :array
    attribute :ip, :array

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

      raise Discourse::InvalidParameters.new(key) if value.empty? || value.size > DIMENSION_LIMIT

      value.map { |item| normalize_filter_value(key, item) }.uniq
    end

    def normalize_filter_value(key, value)
      return "" if %i[referrer language].include?(key) && value == ""
      raise Discourse::InvalidParameters.new(key) if value.blank?

      case key
      when :traffic_type
        traffic_type = value.to_s
        raise Discourse::InvalidParameters.new(key) if !TRAFFIC_TYPE_VALUES.include?(traffic_type)
        traffic_type
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
      when :language
        language = value.to_s
        if language.length > BrowserPageviewEvent::MAX_LANGUAGE_LENGTH
          raise Discourse::InvalidParameters.new(key)
        end
        language
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
      partial_data:
        partial_data(
          row.fetch("pageview_limited"),
          pageview_limit_start_at: row["oldest_pageview_at"],
          start_date: params.start_date,
        ),
      summary: row.fetch("summary"),
      series: row.fetch("series"),
      series_colors: series_colors,
      dimensions: decorate_dimensions(row.fetch("dimensions")),
    }
    if filters[:language]
      filters = filters.merge(language: row.fetch("normalized_language_filters"))
    end
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
    cap = SiteSetting.site_traffic_explorer_event_limit

    {
      start_date: effective_start_date,
      end_date: end_date + 1.day,
      cap: cap,
      site_host: BrowserPageviewEventUrlNormalizer.normalize_host(Discourse.current_hostname),
      top_url_filtered: filters[:top_url].present?,
      top_urls: filters[:top_url].presence || [nil],
      entry_url_filtered: filters[:entry_url].present?,
      entry_urls: filters[:entry_url].presence || [nil],
      referrer_filtered: filters[:referrer].present?,
      referrers: filters[:referrer].presence || [nil],
      country_filtered: filters[:country].present?,
      countries: filters[:country].presence || [nil],
      network_filtered: filters[:network].present?,
      network_asns: filters[:network].presence || [nil],
      browser_filtered: filters[:browser].present?,
      browsers:
        filters[:browser]&.map { |browser| BrowserPageviewEvent.browsers.fetch(browser) } || [nil],
      language_filtered: filters[:language].present?,
      languages: filters[:language].presence || [nil],
      ip_filtered: filters[:ip].present?,
      ip_addresses: filters[:ip].presence || [nil],
      traffic_type_filtered: filters[:traffic_type].present?,
      include_logged_in: filters[:traffic_type]&.include?("logged_in"),
      include_anonymous: filters[:traffic_type]&.include?("anonymous"),
      include_likely_crawler: filters[:traffic_type]&.include?("likely_crawler"),
      crawler_detection_enabled: CrawlerScorer.enabled?,
      crawler_threshold: CrawlerScorer::BOT_SCORE_THRESHOLD,
      bounce_threshold:
        BrowserPageviewSessionEngagementDailyRollup.bounce_engaged_seconds_threshold,
      dimension_limit: DIMENSION_LIMIT,
    }
  end

  def filter_predicate
    predicates = {
      top_url: "(NOT :top_url_filtered OR normalized_url IN (:top_urls))",
      entry_url: "(NOT :entry_url_filtered OR entry_url IN (:entry_urls))",
      referrer: "(NOT :referrer_filtered OR referrer IN (:referrers))",
      country: "(NOT :country_filtered OR country_code IN (:countries))",
      network: "(NOT :network_filtered OR asn IN (:network_asns))",
      browser: "(NOT :browser_filtered OR browser IN (:browsers))",
      language: "(NOT :language_filtered OR language IN (SELECT language FROM language_filters))",
      ip: "(NOT :ip_filtered OR host(ip_address) IN (:ip_addresses))",
      traffic_type: <<~SQL.squish,
          (
            NOT :traffic_type_filtered
            OR (:include_logged_in AND NOT likely_crawler AND user_id IS NOT NULL)
            OR (:include_anonymous AND NOT likely_crawler AND user_id IS NULL)
            OR (:include_likely_crawler AND likely_crawler)
          )
        SQL
    }

    predicates.values.join("\n          AND ")
  end

  def normalized_language_sql(column)
    normalized_language = "replace(#{column}, '_', '-')"

    <<~SQL.squish
      CASE
        WHEN #{normalized_language} ~ '^[A-Za-z]{2,8}(?:-[A-Za-z]{3}){0,3}(?:-[A-Za-z]{4})?(?:-[A-Za-z0-9]{1,8})*$'
        THEN
          lower(split_part(#{normalized_language}, '-', 1)) ||
          CASE
            WHEN substring(
              #{normalized_language}
              FROM '^[A-Za-z]{2,8}(?:-[A-Za-z]{3}){0,3}-([A-Za-z]{4})(?:-|$)'
            ) IS NOT NULL
            THEN '-' || initcap(lower(substring(
              #{normalized_language}
              FROM '^[A-Za-z]{2,8}(?:-[A-Za-z]{3}){0,3}-([A-Za-z]{4})(?:-|$)'
            )))
            ELSE ''
          END
        ELSE COALESCE(#{column}, '')
      END
    SQL
  end

  def query(start_date:, end_date:)
    source_condition =
      BrowserPageviewEvent.rollup_source_condition(table: "bpe", start_date:, end_date:)

    <<~SQL
      WITH language_filters AS MATERIALIZED (
        SELECT DISTINCT #{normalized_language_sql("selected_language.value")} AS language
        FROM unnest(ARRAY[:languages]::text[]) AS selected_language(value)
      ),
      population AS MATERIALIZED (
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
          COALESCE(bpe.browser, #{BrowserPageviewEvent::BROWSER_UNKNOWN}) AS browser,
          #{normalized_language_sql("bpe.language")} AS language,
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
          population.browser,
          population.language,
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
      ),
      dimensioned AS MATERIALIZED (
        SELECT
          classified.created_at,
          classified.session_id,
          classified.user_id,
          classified.normalized_url,
          classified.country_code,
          classified.asn,
          classified.ip_address,
          classified.browser,
          classified.language,
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
      filtered AS NOT MATERIALIZED (
        SELECT *
        FROM dimensioned
        WHERE #{filter_predicate}
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
        (
          SELECT population_boundary.oldest_created_at
          FROM population_boundary
        ) AS oldest_pageview_at,
        (
          SELECT COALESCE(jsonb_agg(language ORDER BY language), '[]'::jsonb)
          FROM language_filters
        ) AS normalized_language_filters,
        jsonb_build_object(
          'country', (
            SELECT COALESCE(jsonb_object_agg(country_code, representative_ip), '{}'::jsonb)
            FROM (
              SELECT country_code, host(MIN(ip_address)) AS representative_ip
              FROM population
              WHERE :country_filtered
                AND country_code IN (:countries)
              GROUP BY country_code
            ) rows
          ),
          'network', (
            SELECT COALESCE(jsonb_object_agg(asn, representative_ip), '{}'::jsonb)
            FROM (
              SELECT asn, host(MIN(ip_address)) AS representative_ip
              FROM population
              WHERE :network_filtered
                AND asn IN (:network_asns)
              GROUP BY asn
            ) rows
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
            ELSE session_summary.engaged_seconds::numeric /
              session_summary.distinct_sessions
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
              SELECT
                normalized_url AS value,
                COUNT(*)::integer AS pageviews
              FROM dimensioned
              WHERE #{filter_predicate}
                AND normalized_url IS NOT NULL
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
              SELECT
                entry_url AS value,
                COUNT(*)::integer AS pageviews
              FROM dimensioned
              WHERE #{filter_predicate}
                AND entry_url IS NOT NULL
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
              SELECT
                referrer AS value,
                COUNT(*)::integer AS pageviews
              FROM dimensioned
              WHERE #{filter_predicate}
                AND referrer IS NOT NULL
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
                host(MIN(ip_address)) AS representative_ip
              FROM dimensioned
              WHERE #{filter_predicate}
                AND country_code IS NOT NULL
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
                host(MIN(ip_address)) AS representative_ip
              FROM dimensioned
              WHERE #{filter_predicate}
                AND asn IS NOT NULL
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
              SELECT
                browser AS value,
                COUNT(*)::integer AS pageviews
              FROM dimensioned
              WHERE #{filter_predicate}
              GROUP BY browser
              ORDER BY pageviews DESC, value
              LIMIT :dimension_limit
            ) rows
          ),
          'languages', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object('value', value, 'pageviews', pageviews)
                ORDER BY pageviews DESC, value
              ),
              '[]'::jsonb
            )
            FROM (
              SELECT
                language AS value,
                COUNT(*)::integer AS pageviews
              FROM dimensioned
              WHERE #{filter_predicate}
              GROUP BY language
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
              SELECT
                host(ip_address) AS value,
                COUNT(*)::integer AS pageviews
              FROM dimensioned
              WHERE #{filter_predicate}
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

  def partial_data(pageview_limited, pageview_limit_start_at:, start_date:)
    retention_limited = start_date < BrowserPageviewEvent.retention_cutoff.to_date
    return nil if !retention_limited && !pageview_limited

    if retention_limited && pageview_limited
      {
        reason: "retention_and_pageview_limit",
        available_start_date: BrowserPageviewEvent.retention_cutoff.to_date.iso8601,
        pageview_limit: SiteSetting.site_traffic_explorer_event_limit,
        pageview_limit_start_at: pageview_limit_start_at.iso8601,
      }
    elsif retention_limited
      {
        reason: "retention",
        available_start_date: BrowserPageviewEvent.retention_cutoff.to_date.iso8601,
      }
    else
      {
        reason: "pageview_limit",
        pageview_limit: SiteSetting.site_traffic_explorer_event_limit,
        pageview_limit_start_at: pageview_limit_start_at.iso8601,
      }
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

      dimension = FILTER_DIMENSIONS.fetch(key)
      value.map do |item|
        canonical_value = key == :network ? "AS#{item}" : item
        representative_ip_key = key == :network ? item.to_s : canonical_value.to_s
        {
          key: key,
          value: canonical_value,
          label:
            dimension_label(
              dimension,
              canonical_value,
              representative_ips.dig(key.to_s, representative_ip_key),
            ),
        }
      end
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
    value = BrowserPageviewEvent.browsers.key(value.to_i) || "unknown" if dimension == "browsers"
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
      I18n.t("browsers.#{value}", default: value)
    when "languages"
      value.presence || I18n.t("admin_site_traffic_explorer.unknown")
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
