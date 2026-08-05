# frozen_string_literal: true

class AdminDashboardSiteTrafficDetail
  EVENT_CAP_SETTING = :admin_site_traffic_event_cap
  MAX_EVENT_CAP = 1_000_000
  MAX_DATE_RANGE_DAYS = 365
  MAX_FILTER_LENGTH = 255
  CACHE_TTL = 1.minute
  LOCK_ACQUIRE_TIMEOUT = 12.seconds
  SINGLE_FLIGHT_VALIDITY = 30.seconds
  RATE_LIMIT_PER_MINUTE = 6
  BOT_SCORE_THRESHOLD = CrawlerScorer::BOT_SCORE_THRESHOLD
  BROWSER_FAMILIES = %w[edge opera firefox chrome safari ie discoursehub unknown].freeze
  BROWSER_CLASSIFIER_VERSION = 1
  CRAWLER_SEMANTICS_VERSION = 3
  RESPONSE_VERSION = 9
  SANITIZER_VERSION = 5
  SESSION_SEMANTICS_VERSION = 2
  TRAFFIC_SOURCE_VERSION = 2
  UNRESOLVED_CUTOVER = Object.new.freeze
  private_constant :BROWSER_FAMILIES, :SINGLE_FLIGHT_VALIDITY, :UNRESOLVED_CUTOVER

  class InvalidRequest < StandardError
  end

  class Timeout < StandardError
  end

  class CutoverResolver
    METADATA_SQL = <<~SQL
      SELECT GREATEST(
        (SELECT MAX(created_at) FROM upcoming_change_events
          WHERE upcoming_change_name = 'dashboard_improvements'
            AND event_type IN (:automatically_promoted, :manual_opt_in)),
        (SELECT MAX(updated_at) FROM site_settings WHERE name = 'dashboard_improvements')
      ) AS enabled_at,
      (SELECT MIN(date) FROM application_requests
        WHERE req_type IN (:logged_in_beacon, :anonymous_beacon)) AS beacon_start_date
    SQL
    private_constant :METADATA_SQL

    def self.resolve(query:)
      return if SiteSetting.use_legacy_pageviews
      return if !UpcomingChanges.enabled?(:dashboard_improvements)
      if !SiteSetting.trigger_browser_pageview_events &&
           !SiteSetting.persist_browser_pageview_events
        return
      end

      row =
        query.call(
          sql: METADATA_SQL,
          binds: {
            automatically_promoted: UpcomingChangeEvent.event_types.fetch("automatically_promoted"),
            manual_opt_in: UpcomingChangeEvent.event_types.fetch("manual_opt_in"),
            logged_in_beacon:
              ApplicationRequest.req_types.fetch("page_view_logged_in_browser_beacon"),
            anonymous_beacon: ApplicationRequest.req_types.fetch("page_view_anon_browser_beacon"),
          },
        ).first || {}
      enabled_at = row["enabled_at"]
      return enabled_at.to_time.utc.to_date.tomorrow if enabled_at

      row["beacon_start_date"]&.to_date
    end
  end
  private_constant :CutoverResolver

  class DisconnectWatcher
    def initialize(client_io:, cancel_connection:)
      @client_io = client_io
      @cancel_connection = cancel_connection
    end

    def start
      @stop_reader, @stop_writer = IO.pipe
      @thread = Thread.new { watch }
      self
    end

    def stop
      @stop_writer.close if @stop_writer && !@stop_writer.closed?
      @thread&.join
    ensure
      @stop_reader.close if @stop_reader && !@stop_reader.closed?
    end

    private

    def watch
      loop do
        readable = IO.select([@client_io, @stop_reader]).first
        return if readable.include?(@stop_reader)
        next if !readable.include?(@client_io)

        value = @client_io.read_nonblock(1, exception: false)
        next if value == :wait_readable
        return cancel if value.nil?
      end
    rescue EOFError, Errno::EBADF, Errno::ECONNRESET, Errno::ENOTCONN, IOError
      cancel
    rescue StandardError
      nil
    end

    def cancel
      @cancel_connection.cancel
    rescue StandardError
      nil
    end
  end
  private_constant :DisconnectWatcher

  class CachedQuery
    Result = Struct.new(:value, :cache_key, :computed, keyword_init: true)
    private_constant :Result

    def initialize(
      request:,
      actor:,
      cache: Discourse.cache,
      synchronizer: DistributedMutex,
      limiter_factory: RateLimiter,
      cache_key: nil,
      coordination_key: nil,
      executor: nil,
      cutover_resolver: CutoverResolver,
      compute:
    )
      @request = request
      @actor = actor
      @cache = cache
      @synchronizer = synchronizer
      @limiter_factory = limiter_factory
      @cache_key = cache_key
      @coordination_key = coordination_key
      @executor = executor
      @cutover_resolver = cutover_resolver
      @compute = compute
    end

    def call
      @synchronizer.synchronize(
        "#{coordination_key}:flight",
        validity: SINGLE_FLIGHT_VALIDITY,
        acquire_timeout: LOCK_ACQUIRE_TIMEOUT,
      ) do
        result =
          executor.execute do |query|
            cutover_date = @cutover_resolver.resolve(query: query)
            exact_cache_key = cache_key(cutover_date)
            cached_value = @cache.read(exact_cache_key)
            if cached_value
              Result.new(value: cached_value, cache_key: exact_cache_key, computed: false)
            else
              compute(cache_key: exact_cache_key, cutover_date: cutover_date, query: query)
            end
          end

        @cache.write(result.cache_key, result.value, expires_in: CACHE_TTL) if result.computed
        result.value
      end
    rescue DistributedMutex::LockTimeout
      raise Timeout
    end

    private

    def executor
      @executor ||= DeadlineExecutor.new
    end

    def cache_key(cutover_date)
      @cache_key ||
        AdminDashboardSiteTrafficDetail.cache_key(
          request: @request,
          actor: @actor,
          cutover_date: cutover_date,
        )
    end

    def coordination_key
      @coordination_key || @cache_key ||
        AdminDashboardSiteTrafficDetail.coordination_key(request: @request, actor: @actor)
    end

    def compute(cache_key:, cutover_date:, query:)
      @limiter_factory.new(
        @actor,
        "admin-site-traffic-detail",
        RATE_LIMIT_PER_MINUTE,
        1.minute,
        apply_limit_to_staff: true,
      ).performed!
      Result.new(
        value: @compute.call(cutover_date: cutover_date, query: query),
        cache_key: cache_key,
        computed: true,
      )
    end
  end

  class DeadlineExecutor
    def initialize(
      deadline_seconds: 10,
      pool: ActiveRecord::Base.connection_pool,
      query: DB,
      clock: Process,
      client_io: nil,
      cancel_connection_class: (defined?(PG::CancelConnection) ? PG::CancelConnection : nil)
    )
      @deadline_seconds = deadline_seconds
      @pool = pool
      @query = query
      @clock = clock
      @client_io = client_io
      @cancel_connection_class = cancel_connection_class
    end

    def execute(statement_sql = nil, statement_binds = {}, &operation)
      deadline = monotonic_time + @deadline_seconds

      @pool.with_connection do |connection|
        result = nil

        connection.transaction(requires_new: true) do
          execute_statement(connection, deadline, "SET TRANSACTION READ ONLY")
          query =
            lambda do |sql:, binds: {}|
              set_timeout(connection, deadline)
              execute_query(connection, sql, binds, deadline)
            end
          result =
            if operation
              operation.call(query)
            else
              query.call(sql: statement_sql, binds: statement_binds)
            end

          raise ActiveRecord::Rollback
        end

        result
      end
    rescue PG::QueryCanceled, ActiveRecord::ConnectionTimeoutError
      raise Timeout
    rescue ActiveRecord::StatementInvalid => error
      raise Timeout if error.message.match?(/statement timeout|query canceled|canceling statement/i)

      raise
    end

    private

    def execute_statement(connection, deadline, statement)
      raise Timeout if remaining_milliseconds(deadline) <= 0

      connection.execute(statement)
      raise Timeout if remaining_milliseconds(deadline) <= 0
    end

    def set_timeout(connection, deadline)
      milliseconds = remaining_milliseconds(deadline)
      raise Timeout if milliseconds <= 0

      execute_statement(connection, deadline, "SET LOCAL statement_timeout = #{milliseconds}")
    end

    def execute_query(connection, sql, binds, deadline)
      raise Timeout if remaining_milliseconds(deadline) <= 0

      watcher, cancel_connection = disconnect_watcher(connection)
      begin
        result = @query.query_hash(sql, binds)
      ensure
        watcher&.stop
        finish_cancel_connection(cancel_connection)
      end
      raise Timeout if remaining_milliseconds(deadline) <= 0

      result
    end

    def disconnect_watcher(connection)
      client_io = selectable_client_io
      return nil, nil if client_io.nil? || @cancel_connection_class.nil?

      cancel_connection = @cancel_connection_class.new(connection.raw_connection)
      watcher =
        DisconnectWatcher.new(client_io: client_io, cancel_connection: cancel_connection).start
      [watcher, cancel_connection]
    rescue StandardError
      finish_cancel_connection(cancel_connection)
      [nil, nil]
    end

    def selectable_client_io
      return if @client_io.nil? || !@client_io.respond_to?(:to_io)

      client_io = @client_io.to_io
      client_io if client_io.respond_to?(:read_nonblock) && !client_io.closed?
    rescue IOError
      nil
    end

    def finish_cancel_connection(cancel_connection)
      cancel_connection&.finish
    rescue StandardError
      nil
    end

    def remaining_milliseconds(deadline)
      ((deadline - monotonic_time) * 1000).ceil
    end

    def monotonic_time
      @clock.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  class Request
    FILTERS = %w[top_url entry_url referrer country asn browser ip].freeze
    KEYS = %w[start_date end_date filters].freeze
    MAX_STORED_ASN = 2_147_483_647
    private_constant :MAX_STORED_ASN

    attr_reader :start_date, :end_date, :filters

    def self.parse(value)
      values = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value
      raise InvalidRequest unless values.is_a?(Hash)

      values = values.stringify_keys
      raise InvalidRequest unless values.keys.sort == KEYS.sort && values["filters"].is_a?(Hash)

      filters = values["filters"].stringify_keys
      unless (filters.keys - FILTERS).empty? &&
               filters.values.all? { |filter| filter.is_a?(String) }
        raise InvalidRequest
      end

      new(start_date: values["start_date"], end_date: values["end_date"], filters:)
    end

    def initialize(start_date:, end_date:, filters:)
      @start_date = parse_date(start_date)
      @end_date = parse_date(end_date)
      if @end_date < @start_date || @end_date > Date.current ||
           (@end_date - @start_date).to_i > MAX_DATE_RANGE_DAYS
        raise InvalidRequest
      end

      @filters = filters.transform_values { |value| validate_filter(value) }.freeze
      validate_filters
    end

    private

    def parse_date(value)
      raise InvalidRequest unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      Date.iso8601(value)
    rescue Date::Error
      raise InvalidRequest
    end

    def validate_filter(value)
      if value.blank? || value.bytesize > MAX_FILTER_LENGTH || !value.valid_encoding? ||
           value.match?(/[\x00-\x1f\x7f*]/)
        raise InvalidRequest
      end

      value
    end

    def validate_filters
      raise InvalidRequest if @filters["country"] && !@filters["country"].match?(/\A[A-Z]{2}\z/)
      if (asn = @filters["asn"]) &&
           (!asn.match?(/\AAS[1-9]\d*\z/) || asn.delete_prefix("AS").to_i > MAX_STORED_ASN)
        raise InvalidRequest
      end
      raise InvalidRequest if @filters["browser"] && !BROWSER_FAMILIES.include?(@filters["browser"])

      if (ip = @filters["ip"])
        parsed = IPAddr.new(ip)
        raise InvalidRequest unless parsed.to_s == ip
      end

      %w[top_url entry_url].each do |filter_name|
        if (path = @filters[filter_name])
          unless AdminDashboardSiteTrafficDetail.canonical_filter_path(path) == path
            raise InvalidRequest
          end
        end
      end

      if (referrer = @filters["referrer"])
        unless AdminDashboardSiteTrafficDetail.canonical_referrer_domain(referrer) == referrer
          raise InvalidRequest
        end
      end
    rescue IPAddr::Error
      raise InvalidRequest
    end
  end

  def self.canonical_filter_path(value)
    if !value.valid_encoding? || value.match?(/[\x00-\x1f\x7f\\<>"'\s%]/) || !value.start_with?("/")
      return
    end
    if value.include?("?") || value.include?("#") || value.match?(%r{\A//|://|/@|/\.\.?(/|\z)})
      return
    end

    path = value.chomp("/").presence || "/"
    return if sensitive_path?(path) || !public_path_shape?(path)

    path
  end

  def self.canonical_referrer_domain(value)
    unless value.match?(/\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/)
      return
    end
    return unless BrowserPageviewReferrerInspector.normalize_host(value) == value

    value
  end

  def self.public_path_shape?(path)
    path.match?(
      %r{\A/(?:categories|latest|hot|top|search|about|faq|guidelines|rules|conduct|tos|privacy|u|g|tags|badges|c|latest\.rss|hot\.rss|top\.rss|posts\.rss)\z},
    ) || path.match?(%r{\A/top/(?:all|yearly|quarterly|monthly|weekly|daily)\z}) ||
      path.match?(%r{\A/t/(?:[1-9]\d*|[A-Za-z0-9_-]+/[1-9]\d*)(?:/[1-9]\d*)?\z}) ||
      path.match?(
        %r{\A/c/(?:[A-Za-z0-9_-]+/)+[1-9]\d*(?:/(?:none|all|subcategories|(?:none/)?l/(?:latest|hot|top)(?:/(?:all|yearly|quarterly|monthly|weekly|daily))?))?\z},
      ) || path.match?(%r{\A/pub/[A-Za-z0-9_-]+\z})
  end

  def self.sensitive_path?(path)
    if path.match?(
         %r{\A/(?:admin|session|auth|login|password|reset|invites?(?:/|$)|user-api-key|api(?:/|$)|uploads?/private|private-uploads?)}i,
       )
      return true
    end
    if path.match?(%r{\A/u/[^/]+/(?:preferences|security|account|email|password)(?:/|\z)}i)
      return true
    end

    false
  end

  def self.cache_key(request:, actor:, cutover_date: UNRESOLVED_CUTOVER)
    if cutover_date.equal?(UNRESOLVED_CUTOVER)
      cutover_date = BrowserPageviewEvent.beacon_cutover_date
    end
    values = cache_key_values(request: request, actor: actor) + [cutover_date]
    "admin-site-traffic-detail:v#{RESPONSE_VERSION}:#{Digest::SHA256.hexdigest(MultiJson.dump(values))}"
  end

  def self.coordination_key(request:, actor:)
    values = cache_key_values(request: request, actor: actor)
    "admin-site-traffic-detail-coordination:v#{RESPONSE_VERSION}:#{Digest::SHA256.hexdigest(MultiJson.dump(values))}"
  end

  def self.cache_key_values(request:, actor:)
    [
      RESPONSE_VERSION,
      SANITIZER_VERSION,
      TRAFFIC_SOURCE_VERSION,
      BROWSER_CLASSIFIER_VERSION,
      CRAWLER_SEMANTICS_VERSION,
      SESSION_SEMANTICS_VERSION,
      BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD.to_i,
      RailsMultisite::ConnectionManagement.current_db,
      Discourse.current_hostname,
      BrowserPageviewReferrerInspector::VERSION,
      BOT_SCORE_THRESHOLD,
      UpcomingChanges.enabled?(:improved_crawler_detection),
      SiteSetting.clean_up_browser_pageview_events,
      RATE_LIMIT_PER_MINUTE,
      request.start_date.iso8601,
      request.end_date.iso8601,
      Request::FILTERS.map { |name| [name, request.filters[name]] },
      actor.id,
      actor.admin?,
      event_cap,
      SiteSetting.use_legacy_pageviews,
      UpcomingChanges.enabled?(:dashboard_improvements),
      SiteSetting.trigger_browser_pageview_events,
      SiteSetting.persist_browser_pageview_events,
      Discourse.base_path,
      Discourse.base_url,
      RailsMultisite::ConnectionManagement.current_db_hostnames,
    ]
  end
  private_class_method :cache_key_values

  def self.event_cap
    [[SiteSetting.public_send(EVENT_CAP_SETTING).to_i, 1].max, MAX_EVENT_CAP].min
  end

  def initialize(request:, executor: DeadlineExecutor.new)
    @request = request
    @executor = executor
  end

  def call(cutover_date: nil, query: nil)
    return build_response(query: query, cutover_date: cutover_date) if query

    @executor.execute do |bounded_query|
      resolved_cutover_date = CutoverResolver.resolve(query: bounded_query)
      build_response(query: bounded_query, cutover_date: resolved_cutover_date)
    end
  end

  private

  def build_response(query:, cutover_date:)
    row =
      query.call(sql: analytics_sql, binds: analytics_binds(cutover_date: cutover_date)).first || {}
    row = row.symbolize_keys

    {
      analysis: analysis(row),
      filters: @request.filters,
      summary: summary(row),
      series: row.fetch(:series, []),
      dimensions: dimensions(row),
    }
  end

  def analytics_sql
    <<~SQL
      WITH RECURSIVE candidates AS MATERIALIZED (
        SELECT bpe.id, bpe.created_at, bpe.url, bpe.country_code, bpe.asn, bpe.ip_address,
               bpe.user_agent, bpe.user_id, bpe.session_id, bpe.score, bpe.normalized_referrer,
               bpe.normalized_referrer_version
        FROM browser_pageview_events bpe
        WHERE bpe.created_at >= :start_at AND bpe.created_at < :end_at
          AND ((:cutover_date IS NULL AND bpe.source = #{BrowserPageviewEvent::SOURCE_PIGGYBACK})
            OR (:cutover_date IS NOT NULL AND ((bpe.created_at < :cutover_date AND bpe.source = #{BrowserPageviewEvent::SOURCE_PIGGYBACK})
              OR (bpe.created_at >= :cutover_date AND bpe.source = #{BrowserPageviewEvent::SOURCE_BEACON}))))
        ORDER BY bpe.created_at DESC, bpe.id DESC
        LIMIT :event_cap_plus_one
      ), available AS (
        SELECT MIN(bpe.created_at) AS available_start_at, MAX(bpe.created_at) AS available_end_at
        FROM browser_pageview_events bpe
        WHERE bpe.created_at >= :start_at AND bpe.created_at < :end_at
          AND ((:cutover_date IS NULL AND bpe.source = #{BrowserPageviewEvent::SOURCE_PIGGYBACK})
            OR (:cutover_date IS NOT NULL AND ((bpe.created_at < :cutover_date AND bpe.source = #{BrowserPageviewEvent::SOURCE_PIGGYBACK})
              OR (bpe.created_at >= :cutover_date AND bpe.source = #{BrowserPageviewEvent::SOURCE_BEACON}))))
      ), normalized_events AS MATERIALIZED (
        SELECT path_inputs.id, path_inputs.created_at, path_inputs.country_code, path_inputs.asn,
          path_inputs.ip_address, path_inputs.user_agent, path_inputs.user_id,
          path_inputs.session_id, path_inputs.score, path_inputs.normalized_referrer,
          path_inputs.normalized_referrer_version, CASE
            WHEN path_inputs.url ~ ('[[' || chr(58) || 'cntrl' || chr(58) || ']]')
              OR path_inputs.raw_path !~ '^/' OR path_inputs.raw_path ~ '[\\<>"''\\s%]'
              OR path_inputs.raw_path ~ '^//' OR path_inputs.raw_path ~ '/\\.\\.?(/|$)'
              THEN '[redacted]'
            WHEN path_inputs.absolute_url AND :base_path <> ''
              AND path_inputs.raw_path <> :base_path
              AND left(path_inputs.raw_path, length(:base_path) + 1) <> :base_path || '/'
              THEN '[redacted]'
            ELSE COALESCE(
              NULLIF(
                regexp_replace(
                  CASE
                    WHEN path_inputs.absolute_url AND :base_path <> ''
                      THEN substring(path_inputs.raw_path FROM length(:base_path) + 1)
                    ELSE path_inputs.raw_path
                  END,
                  '/+$',
                  ''
                ),
                ''
              ),
              '/'
            )
          END AS normalized_path
        FROM (
          SELECT candidates.*, candidates.url ~* '^https?://' AS absolute_url,
            COALESCE(
              NULLIF(
                split_part(
                  split_part(
                    CASE
                      WHEN candidates.url ~ '^/' THEN candidates.url
                      WHEN candidates.url ~* '^https?://'
                        AND regexp_replace(candidates.url, '^(https?://[^/?#]+).*', '\\1') IN (SELECT jsonb_array_elements_text(CAST(:trusted_origins AS jsonb)))
                        THEN regexp_replace(candidates.url, '^https?://[^/?#]+', '')
                      ELSE '[redacted]'
                    END,
                    '?',
                    1
                  ),
                  '#',
                  1
                ),
                ''
              ),
              '/'
            ) AS raw_path
          FROM candidates
          ORDER BY created_at DESC, id DESC
          LIMIT :event_cap
        ) path_inputs
      ), category_paths AS (
        SELECT categories.id, categories.slug::text AS slug_path, categories.read_restricted AS read_restricted
        FROM categories
        WHERE categories.parent_category_id IS NULL
        UNION ALL
        SELECT child.id, category_paths.slug_path || '/' || child.slug, category_paths.read_restricted OR child.read_restricted
        FROM categories child
        INNER JOIN category_paths ON child.parent_category_id = category_paths.id
      ), safe_paths AS MATERIALIZED (
        SELECT canonical_paths.normalized_path, CASE
          WHEN canonical_paths.normalized_path ~ '^/$|^/(categories|latest|hot|top|search|about|privacy|tos|faq|guidelines|rules|conduct|u|g|tags|badges|c)$|^/top/(all|yearly|quarterly|monthly|weekly|daily)$|^/(latest|top|hot|posts)\.rss$' THEN canonical_paths.normalized_path
          WHEN canonical_paths.normalized_path ~ '^/t/[1-9][0-9]*(/[1-9][0-9]*)?$'
            AND topic.id IS NOT NULL AND topic.deleted_at IS NULL AND topic.visible AND topic.archetype = 'regular' AND shared_draft.topic_id IS NULL
            AND (topic.category_id IS NULL OR topic_category_path.id IS NOT NULL AND NOT topic_category_path.read_restricted)
            AND (topic_post.id IS NOT NULL OR canonical_paths.normalized_path !~ '^/t/[1-9][0-9]*/[1-9][0-9]*$') THEN canonical_paths.normalized_path
          WHEN canonical_paths.normalized_path ~ '^/t/[A-Za-z0-9_-]+/[1-9][0-9]*(/[1-9][0-9]*)?$'
            AND topic.id IS NOT NULL AND topic.deleted_at IS NULL AND topic.visible AND topic.archetype = 'regular' AND shared_draft.topic_id IS NULL
            AND (topic.category_id IS NULL OR topic_category_path.id IS NOT NULL AND NOT topic_category_path.read_restricted)
            AND topic.slug = substring(canonical_paths.normalized_path FROM '^/t/([A-Za-z0-9_-]+)/')
            AND (topic_post.id IS NOT NULL OR canonical_paths.normalized_path !~ '^/t/[A-Za-z0-9_-]+/[1-9][0-9]*/[1-9][0-9]*$') THEN canonical_paths.normalized_path
          WHEN category_paths.id IS NOT NULL AND NOT category_paths.read_restricted
            AND (canonical_paths.normalized_path = '/c/' || category_paths.slug_path || '/' || category_paths.id::text
              OR (left(canonical_paths.normalized_path, length('/c/' || category_paths.slug_path || '/' || category_paths.id::text) + 1) = '/c/' || category_paths.slug_path || '/' || category_paths.id::text || '/'
                AND substring(canonical_paths.normalized_path FROM length('/c/' || category_paths.slug_path || '/' || category_paths.id::text) + 2) ~ '^(none|all|subcategories|(none/)?l/(latest|hot|top)(/(all|yearly|quarterly|monthly|weekly|daily))?)$')) THEN canonical_paths.normalized_path
          WHEN published_pages.id IS NOT NULL AND published_pages.public
            AND canonical_paths.normalized_path = '/pub/' || published_pages.slug
            THEN canonical_paths.normalized_path
          ELSE '[redacted]'
        END AS safe_path
        FROM (SELECT DISTINCT normalized_path FROM normalized_events) canonical_paths
        LEFT JOIN topics topic ON topic.id = COALESCE(
          NULLIF(substring(canonical_paths.normalized_path FROM '^/t/([1-9][0-9]*)(?:/[1-9][0-9]*)?$'), '')::numeric,
          NULLIF(substring(canonical_paths.normalized_path FROM '^/t/[A-Za-z0-9_-]+/([1-9][0-9]*)(?:/[1-9][0-9]*)?$'), '')::numeric
        )
        LEFT JOIN posts topic_post ON topic_post.topic_id = topic.id
          AND topic_post.post_number = COALESCE(
            NULLIF(substring(canonical_paths.normalized_path FROM '^/t/[1-9][0-9]*/([1-9][0-9]*)$'), '')::numeric,
            NULLIF(substring(canonical_paths.normalized_path FROM '^/t/[A-Za-z0-9_-]+/[1-9][0-9]*/([1-9][0-9]*)$'), '')::numeric
          )
          AND topic_post.deleted_at IS NULL AND NOT topic_post.hidden
        LEFT JOIN shared_drafts shared_draft ON shared_draft.topic_id = topic.id
        LEFT JOIN category_paths topic_category_path ON topic_category_path.id = topic.category_id
        LEFT JOIN category_paths ON category_paths.id = NULLIF((regexp_match(canonical_paths.normalized_path, '^/c/([A-Za-z0-9_-]+/)+([1-9][0-9]*)(/(none|all|subcategories|(none/)?l/(latest|hot|top)(/(all|yearly|quarterly|monthly|weekly|daily))?))?$'))[2], '')::numeric
        LEFT JOIN published_pages ON published_pages.slug = NULLIF(substring(canonical_paths.normalized_path FROM '^/pub/([A-Za-z0-9_-]+)$'), '')
      ), classified AS MATERIALIZED (
        SELECT normalized_events.id, normalized_events.created_at,
          normalized_events.country_code, normalized_events.asn, normalized_events.ip_address,
          normalized_events.user_id, normalized_events.session_id, normalized_events.score,
          safe_paths.safe_path, CASE
             WHEN normalized_events.user_agent ILIKE '%edg%' THEN 'edge'
             WHEN normalized_events.user_agent ILIKE '%opera%' OR normalized_events.user_agent ILIKE '%opr%' THEN 'opera'
             WHEN normalized_events.user_agent ILIKE '%firefox%' THEN 'firefox'
             WHEN normalized_events.user_agent ILIKE '%chrome%' OR normalized_events.user_agent ILIKE '%crios%' THEN 'chrome'
             WHEN normalized_events.user_agent ILIKE '%safari%' THEN 'safari'
             WHEN normalized_events.user_agent ILIKE '%msie%' OR normalized_events.user_agent ILIKE '%trident%' THEN 'ie'
             WHEN normalized_events.user_agent ILIKE '%discourse%' THEN 'discoursehub'
             ELSE 'unknown' END AS browser_family,
        CASE
          WHEN normalized_events.normalized_referrer_version = :referrer_version
            AND normalized_events.normalized_referrer IS NOT NULL
            AND split_part(normalized_events.normalized_referrer, '/', 1) NOT IN (SELECT jsonb_array_elements_text(CAST(:internal_hosts AS jsonb)))
            AND split_part(normalized_events.normalized_referrer, '/', 1) <> ''
            AND split_part(normalized_events.normalized_referrer, '/', 1) ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
            THEN split_part(normalized_events.normalized_referrer, '/', 1)
          ELSE 'Direct / unknown'
        END AS traffic_source
        FROM normalized_events
        INNER JOIN safe_paths USING (normalized_path)
      ), entries AS MATERIALIZED (
        SELECT DISTINCT ON (session_id) * FROM classified
        WHERE session_id IS NOT NULL AND session_id <> ''
        ORDER BY session_id, created_at ASC, id ASC
      ), facet_events AS MATERIALIZED (
        SELECT classified.*, entries.safe_path AS entry_path,
          entries.traffic_source AS entry_source
        FROM classified
        LEFT JOIN entries ON entries.id = classified.id
      ), session_rollup AS (
        SELECT session_id, MIN(created_at) AS first_observed_at, COUNT(*) AS pageviews FROM classified
        WHERE session_id IS NOT NULL AND session_id <> '' GROUP BY session_id
      ), session_stats AS (
        SELECT COUNT(*) FILTER (WHERE session_rollup.first_observed_at < :session_started_before)::bigint AS distinct_sessions,
          COUNT(*) FILTER (WHERE session_rollup.first_observed_at < :session_started_before AND session_rollup.pageviews = 1 AND COALESCE(engagement.engaged_seconds, 0) < 10)::bigint AS bounced_sessions,
          COALESCE(SUM(engagement.engaged_seconds) FILTER (WHERE session_rollup.first_observed_at < :session_started_before), 0)::bigint AS engaged_seconds_total,
          COUNT(*) FILTER (WHERE session_rollup.first_observed_at >= :session_started_before)::bigint AS excluded_unsettled_session_count
        FROM session_rollup LEFT JOIN browser_pageview_session_engagements engagement USING (session_id)
      ), daily AS MATERIALIZED (
        SELECT created_at::date AS date, COUNT(*)::bigint AS pageviews,
          COUNT(*) FILTER (WHERE (score IS NULL OR score <= #{BOT_SCORE_THRESHOLD}) AND user_id IS NOT NULL)::bigint AS logged_in_human_pageviews,
          COUNT(*) FILTER (WHERE (score IS NULL OR score <= #{BOT_SCORE_THRESHOLD}) AND user_id IS NULL)::bigint AS anonymous_human_pageviews,
          COUNT(*) FILTER (WHERE score > #{BOT_SCORE_THRESHOLD})::bigint AS likely_crawler_pageviews
        FROM facet_events
        WHERE (:top_url IS NULL OR safe_path = :top_url)
          AND (:entry_url IS NULL OR entry_path = :entry_url)
          AND (:referrer IS NULL OR entry_source = :referrer)
          AND (:country IS NULL OR country_code = :country)
          AND (:asn IS NULL OR asn = :asn) AND (:browser IS NULL OR browser_family = :browser)
          AND (:ip IS NULL OR ip_address = CAST(:ip AS inet))
        GROUP BY created_at::date
      ), filtered_summary AS (
        SELECT COALESCE(SUM(pageviews), 0)::bigint AS pageviews,
          COALESCE(SUM(logged_in_human_pageviews), 0)::bigint AS logged_in_human_pageviews,
          COALESCE(SUM(anonymous_human_pageviews), 0)::bigint AS anonymous_human_pageviews,
          COALESCE(SUM(likely_crawler_pageviews), 0)::bigint AS likely_crawler_pageviews
        FROM daily
      ), dimension_rows AS (
        (SELECT 'top_urls' AS dimension, safe_path AS value, safe_path AS label, COUNT(*) FILTER (WHERE (:entry_url IS NULL OR entry_path = :entry_url) AND (:referrer IS NULL OR entry_source = :referrer) AND (:country IS NULL OR country_code = :country) AND (:asn IS NULL OR asn = :asn) AND (:browser IS NULL OR browser_family = :browser) AND (:ip IS NULL OR ip_address = CAST(:ip AS inet)))::bigint AS pageviews, safe_path <> '[redacted]' AS filterable, NULL::text AS lookup_ip FROM facet_events GROUP BY safe_path ORDER BY pageviews DESC, label ASC LIMIT 50)
        UNION ALL (SELECT 'entry_urls', entry_path, entry_path, COUNT(*) FILTER (WHERE (:top_url IS NULL OR safe_path = :top_url) AND (:referrer IS NULL OR entry_source = :referrer) AND (:country IS NULL OR country_code = :country) AND (:asn IS NULL OR asn = :asn) AND (:browser IS NULL OR browser_family = :browser) AND (:ip IS NULL OR ip_address = CAST(:ip AS inet)))::bigint AS pageviews, entry_path <> '[redacted]', NULL::text FROM facet_events WHERE entry_path IS NOT NULL GROUP BY entry_path ORDER BY pageviews DESC, entry_path ASC LIMIT 50)
        UNION ALL (SELECT 'traffic_sources', entry_source, entry_source, COUNT(*) FILTER (WHERE (:top_url IS NULL OR safe_path = :top_url) AND (:entry_url IS NULL OR entry_path = :entry_url) AND (:country IS NULL OR country_code = :country) AND (:asn IS NULL OR asn = :asn) AND (:browser IS NULL OR browser_family = :browser) AND (:ip IS NULL OR ip_address = CAST(:ip AS inet)))::bigint AS pageviews, entry_source <> 'Direct / unknown', NULL::text FROM facet_events WHERE entry_source IS NOT NULL GROUP BY entry_source ORDER BY pageviews DESC, entry_source ASC LIMIT 50)
        UNION ALL (SELECT 'countries', country_code, country_code, COUNT(*) FILTER (WHERE (:top_url IS NULL OR safe_path = :top_url) AND (:entry_url IS NULL OR entry_path = :entry_url) AND (:referrer IS NULL OR entry_source = :referrer) AND (:asn IS NULL OR asn = :asn) AND (:browser IS NULL OR browser_family = :browser) AND (:ip IS NULL OR ip_address = CAST(:ip AS inet)))::bigint AS pageviews, true, NULL::text FROM facet_events WHERE country_code IS NOT NULL AND country_code <> '' GROUP BY country_code ORDER BY pageviews DESC, country_code ASC LIMIT 50)
        UNION ALL (SELECT 'networks', 'AS' || asn::text, 'AS' || asn::text, COUNT(*) FILTER (WHERE (:top_url IS NULL OR safe_path = :top_url) AND (:entry_url IS NULL OR entry_path = :entry_url) AND (:referrer IS NULL OR entry_source = :referrer) AND (:country IS NULL OR country_code = :country) AND (:browser IS NULL OR browser_family = :browser) AND (:ip IS NULL OR ip_address = CAST(:ip AS inet)))::bigint AS pageviews, true, host(MIN(ip_address)) FROM facet_events WHERE asn IS NOT NULL GROUP BY asn ORDER BY pageviews DESC, 'AS' || asn::text ASC LIMIT 50)
        UNION ALL (SELECT 'browsers', browser_family, browser_family, COUNT(*) FILTER (WHERE (:top_url IS NULL OR safe_path = :top_url) AND (:entry_url IS NULL OR entry_path = :entry_url) AND (:referrer IS NULL OR entry_source = :referrer) AND (:country IS NULL OR country_code = :country) AND (:asn IS NULL OR asn = :asn) AND (:ip IS NULL OR ip_address = CAST(:ip AS inet)))::bigint AS pageviews, true, NULL::text FROM facet_events GROUP BY browser_family ORDER BY pageviews DESC, browser_family ASC LIMIT 50)
        UNION ALL (SELECT 'ip_addresses', host(ip_address), host(ip_address), COUNT(*) FILTER (WHERE (:top_url IS NULL OR safe_path = :top_url) AND (:entry_url IS NULL OR entry_path = :entry_url) AND (:referrer IS NULL OR entry_source = :referrer) AND (:country IS NULL OR country_code = :country) AND (:asn IS NULL OR asn = :asn) AND (:browser IS NULL OR browser_family = :browser))::bigint AS pageviews, true, NULL::text FROM facet_events WHERE ip_address IS NOT NULL GROUP BY ip_address ORDER BY pageviews DESC, host(ip_address) ASC LIMIT 50)
      ), dimensions AS (
        SELECT dimension, jsonb_agg(jsonb_build_object('value', CASE WHEN value = '[redacted]' THEN NULL ELSE value END, 'label', CASE WHEN value = '[redacted]' THEN 'Private or sensitive page' ELSE label END, 'pageviews', pageviews, 'filterable', filterable, 'lookup_ip', lookup_ip) ORDER BY pageviews DESC, label ASC) AS rows
        FROM dimension_rows GROUP BY dimension
      )
      SELECT available.*, (SELECT COUNT(*) FROM candidates) > :event_cap AS cap_truncated,
        (SELECT COUNT(*) FROM normalized_events) AS analyzed_event_count, (SELECT MIN(created_at) FROM normalized_events) AS analyzed_start_at,
        (SELECT MAX(created_at) FROM normalized_events) AS analyzed_end_at, (SELECT COUNT(*) FILTER (WHERE score IS NULL) FROM normalized_events) AS unscored_event_count,
        (SELECT COUNT(*) FILTER (WHERE created_at >= :crawler_scoring_eligible_before) FROM normalized_events) AS crawler_scoring_delayed_event_count,
        filtered_summary.*, session_stats.*, COALESCE((SELECT jsonb_agg(jsonb_build_object('date', date::text, 'pageviews', pageviews, 'logged_in_human_pageviews', logged_in_human_pageviews, 'anonymous_human_pageviews', anonymous_human_pageviews, 'likely_crawler_pageviews', likely_crawler_pageviews) ORDER BY date) FROM daily), '[]'::jsonb) AS series,
        COALESCE((SELECT rows FROM dimensions WHERE dimension = 'top_urls'), '[]'::jsonb) AS top_urls,
        COALESCE((SELECT rows FROM dimensions WHERE dimension = 'entry_urls'), '[]'::jsonb) AS entry_urls,
        COALESCE((SELECT rows FROM dimensions WHERE dimension = 'traffic_sources'), '[]'::jsonb) AS traffic_sources,
        COALESCE((SELECT rows FROM dimensions WHERE dimension = 'countries'), '[]'::jsonb) AS countries,
        COALESCE((SELECT rows FROM dimensions WHERE dimension = 'networks'), '[]'::jsonb) AS networks,
        COALESCE((SELECT rows FROM dimensions WHERE dimension = 'browsers'), '[]'::jsonb) AS browsers,
        COALESCE((SELECT rows FROM dimensions WHERE dimension = 'ip_addresses'), '[]'::jsonb) AS ip_addresses
      FROM available CROSS JOIN filtered_summary CROSS JOIN session_stats
    SQL
  end

  def analytics_binds(cutover_date:)
    filters = @request.filters
    now = Time.zone.now
    {
      start_at: @request.start_date.beginning_of_day,
      end_at: @request.end_date.tomorrow.beginning_of_day,
      event_cap: self.class.event_cap,
      event_cap_plus_one: self.class.event_cap + 1,
      cutover_date: cutover_date,
      top_url: filters["top_url"],
      entry_url: filters["entry_url"],
      referrer: filters["referrer"],
      country: filters["country"],
      asn: filters["asn"]&.delete_prefix("AS")&.to_i,
      browser: filters["browser"],
      ip: filters["ip"],
      referrer_version: BrowserPageviewReferrerInspector::VERSION,
      internal_hosts: MultiJson.dump(internal_referrer_hosts),
      trusted_origins: MultiJson.dump(trusted_origins),
      base_path: Discourse.base_path,
      crawler_scoring_eligible_before: now - BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD,
      session_started_before: now - BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD,
    }
  end

  def trusted_origins
    canonical = URI.parse(Discourse.base_url)
    hosts =
      RailsMultisite::ConnectionManagement.current_db_hostnames +
        [Discourse.current_hostname, canonical.host]
    hosts
      .filter_map do |host|
        normalized_host = canonical_origin_host(host)
        next if normalized_host.blank?

        port = canonical.port
        default_port = canonical.scheme == "https" ? 443 : 80
        "#{canonical.scheme}://#{normalized_host}#{port == default_port ? "" : ":#{port}"}"
      end
      .uniq
  end

  def canonical_origin_host(host)
    return if host.blank?

    Addressable::URI.parse("http://#{host}").normalized_host&.delete_suffix(".")
  rescue Addressable::URI::InvalidURIError
    nil
  end

  def internal_referrer_hosts
    (RailsMultisite::ConnectionManagement.current_db_hostnames + [Discourse.current_hostname])
      .filter_map { |host| BrowserPageviewReferrerInspector.normalize_host(host) }
      .uniq
  end

  def analysis(row)
    improved_crawler_detection_enabled = UpcomingChanges.enabled?(:improved_crawler_detection)

    {
      requested_start_date: @request.start_date.iso8601,
      requested_end_date: @request.end_date.iso8601,
      available_start_at: row[:available_start_at],
      available_end_at: row[:available_end_at],
      analyzed_start_at: row[:analyzed_start_at],
      analyzed_end_at: row[:analyzed_end_at],
      analyzed_event_count: row[:analyzed_event_count].to_i,
      event_cap: self.class.event_cap,
      retention_truncated:
        SiteSetting.clean_up_browser_pageview_events &&
          @request.start_date.beginning_of_day < BrowserPageviewEvent.retention_cutoff,
      cap_truncated: row[:cap_truncated],
      capture_scope: "retained_browser_pageviews",
      browser_classifier_semantics: "browser_detection_v#{BROWSER_CLASSIFIER_VERSION}",
      crawler_classification: "likely_crawler_score",
      crawler_classifier_semantics:
        "post_capture_likely_crawler_score_v#{CRAWLER_SEMANTICS_VERSION}",
      request_detected_crawlers_included: false,
      dashboard_crawler_series_scope:
        (
          if improved_crawler_detection_enabled
            "score_based_likely_crawlers_and_request_detected_crawlers"
          else
            "request_detected_crawlers"
          end
        ),
      crawler_classifier_comparable_to_dashboard: improved_crawler_detection_enabled,
      crawler_series_comparable_to_dashboard: false,
      crawler_scoring_state: improved_crawler_detection_enabled ? "active" : "disabled",
      crawler_scoring_delay_seconds: BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD.to_i,
      crawler_scoring_delayed_event_count: row[:crawler_scoring_delayed_event_count].to_i,
      crawler_score_threshold: BOT_SCORE_THRESHOLD,
      crawler_score_operator: "greater_than",
      unscored_event_count: row[:unscored_event_count].to_i,
      unscored_event_semantics: "no_persisted_crawler_score",
      session_scope: "capped_base_unfiltered",
      session_semantics_version: SESSION_SEMANTICS_VERSION,
      session_semantics: "settled_first_observed_capped_base_v#{SESSION_SEMANTICS_VERSION}",
      session_settle_seconds: BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD.to_i,
      excluded_unsettled_session_count: row[:excluded_unsettled_session_count].to_i,
      session_start_semantics: "first_observed_event_in_capped_base",
      capped_slice_can_begin_mid_session: !!row[:cap_truncated],
      entry_event_semantics: "first_observed_event_in_capped_base",
      entry_cap_boundary_limited: !!row[:cap_truncated],
      traffic_source_semantics: "entry_external_normalized_host_v#{TRAFFIC_SOURCE_VERSION}",
    }
  end

  def summary(row)
    {
      pageviews: row[:pageviews].to_i,
      logged_in_human_pageviews: row[:logged_in_human_pageviews].to_i,
      anonymous_human_pageviews: row[:anonymous_human_pageviews].to_i,
      likely_crawler_pageviews: row[:likely_crawler_pageviews].to_i,
      distinct_sessions: row[:distinct_sessions].to_i,
      bounce_rate:
        (
          if row[:distinct_sessions].to_i.zero?
            nil
          else
            (row[:bounced_sessions].to_i * 100.0 / row[:distinct_sessions].to_i).round
          end
        ),
      average_session_duration_seconds:
        (
          if row[:distinct_sessions].to_i.zero?
            nil
          else
            (row[:engaged_seconds_total].to_i.to_f / row[:distinct_sessions].to_i).round
          end
        ),
    }
  end

  def dimensions(row)
    %i[
      top_urls
      entry_urls
      traffic_sources
      countries
      networks
      browsers
      ip_addresses
    ].to_h do |dimension|
      rows = row.fetch(dimension, [])
      rows = rows.map { |dimension_row| present_dimension_row(dimension:, row: dimension_row) }
      [dimension, rows]
    end
  end

  def present_dimension_row(dimension:, row:)
    row = row.symbolize_keys
    lookup_ip = row.delete(:lookup_ip)
    return row if dimension != :networks || lookup_ip.blank?

    expected_asn = row[:value].delete_prefix("AS").to_i
    organization = DiscourseIpInfo.asn_organization(ip: lookup_ip, expected_asn: expected_asn)
    row[:label] = "#{row[:value]} #{organization}" if organization.present?
    row
  end
end
