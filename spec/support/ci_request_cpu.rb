# frozen_string_literal: true

# CI-only reductions of per-request CPU on the in-process test server.
#
# System specs are CPU-bound: 10 workers each drive a browser plus the
# in-process Rails server on a CPU-saturated runner, so wall-clock is gated by
# CPU, not protocol latency. Several per-request instrumentation paths run on
# every controller request the server handles but produce output that is
# unreachable under `RAILS_TEST_LOG_LEVEL=error` (CI) - pure overhead paid
# hundreds of times per page the system specs drive. Neutralize them in CI.
#
# Gated on `DISCOURSE_REDUCE_REQUEST_CPU=1`, which the workflow sets only for
# system-test jobs: backend specs assert directly on MethodProfiler, request
# timing (X-Runtime), and the notification instrumentation neutralized here, so
# they must keep it intact. Individually restorable via
# `DISCOURSE_KEEP_AR_QUERY_LOGS=1` / `DISCOURSE_KEEP_METHOD_PROFILER=1`.
# Query-counting helpers (`spec/support/helpers.rb#track_sql_queries`) attach
# transient subscribers, so they continue to observe queries unchanged.

if ENV["DISCOURSE_REDUCE_REQUEST_CPU"] == "1" && !ENV["DISCOURSE_KEEP_AR_QUERY_LOGS"]
  # ActiveRecord query log tags + verbose query logs are enabled in
  # config/environments/test.rb, but their output is unreachable under
  # RAILS_TEST_LOG_LEVEL=error. The compute is not: every AR query runs the
  # request_path / Thread.current.object_id lambdas and builds an SQL comment,
  # and verbose_query_logs walks the Ruby stack via caller_locations on every
  # log emit. Override QueryLogs.comment to a constant nil so the prepended
  # call(sql, connection) exits in one branch without iterating handlers.
  ActiveRecord.verbose_query_logs = false

  if defined?(ActiveRecord::QueryLogs)
    ActiveRecord::QueryLogs.tags = []
    ActiveRecord::QueryLogs.singleton_class.define_method(:comment) { |_connection| nil }
  end

  # Mirror the production-only optimization from
  # config/initializers/300-perf.rb into CI test runs. Every AR query passes
  # through ActiveSupport::Notifications.instrument("sql.active_record", ...).
  # With AR's LogSubscriber attached, that path allocates a notification Event,
  # dispatches start/finish across subscribers, and ends in
  # ActiveRecord::LogSubscriber#sql - which immediately exits because
  # RAILS_TEST_LOG_LEVEL=error keeps logger.level above the subscriber's :debug
  # threshold. With no subscribers, instrument short-circuits via
  # @notifier.listening?(name) and just yields. track_sql_queries uses
  # Notifications.subscribed { ... } transiently, so query-counting still works.
  ActiveSupport::Notifications.notifier.unsubscribe("sql.active_record")

  # Extend the same unsubscribe to the remaining LogSubscriber events the
  # in-process server dispatches on every request but nothing consumes under
  # RAILS_TEST_LOG_LEVEL=error:
  #
  # * instantiation.active_record fires from find_by_sql once per
  #   record-returning SELECT - dozens per topic/list page.
  # * render_template / render_partial / render_collection / render_layout
  #   .action_view fire for every server-rendered bootstrap-HTML template +
  #   partial on each full page load.
  #
  # No spec/** file subscribes to or asserts on these events.
  %w[
    instantiation.active_record
    render_template.action_view
    render_partial.action_view
    render_collection.action_view
    render_layout.action_view
  ].each { |event| ActiveSupport::Notifications.notifier.unsubscribe(event) }

  # Same idea for the MiniSql path. Every DB.query/DB.exec flows through
  # MiniSqlMultisiteConnection#run, which unconditionally builds the
  # sql.mini_sql notification payload - and sql: is sql_fragment(sql, *params),
  # which for any parameterized query runs ActiveRecord::Base.sanitize_sql_array
  # (regex parameter interpolation). Because that payload is a positional
  # argument it is computed eagerly on every query before instrument checks for
  # listeners. MiniSql ships no LogSubscriber to unsubscribe, so gate the whole
  # instrument behind listening? instead. track_sql_queries attaches a
  # transient sql.mini_sql subscriber, so query-counting blocks stay
  # byte-identical; otherwise the per-query sanitize_sql_array + dispatch are
  # skipped.
  MiniSqlMultisiteConnection.class_eval do
    def run(sql, params)
      if ActiveSupport::Notifications.notifier.listening?("sql.mini_sql")
        ActiveSupport::Notifications.instrument(
          "sql.mini_sql",
          sql: sql_fragment(sql, *params),
          name: "MiniSql",
        )
      end

      super
    end
  end
end

# Neutralize MethodProfiler in CI. Middleware::RequestTracker wraps every
# controller request with MethodProfiler.start/.stop, and Hijack / Jobs::Base
# do the same for hijacked responses and jobs. While a profiler is active, the
# prepended patches on PG::Connection, Redis::Client, RedisClient,
# RubyConnection, Net::HTTP and Excon::Connection record every call with two
# Process.clock_gettimes plus a hash mutation - paid hundreds of times per page
# the system specs drive. MethodProfiler.start also builds a full GC.stat Hash
# (~30 entries) on every request, and lograge reads GC.stat[:heap_live_slots]
# again per request. In CI that timing data only surfaces in the X-Runtime
# header and lograge fields emitted at error level - nothing any spec asserts
# on. No-op start so Thread.current[:_method_profiler] stays nil: every patched
# call takes the single thread-local nil-check fast path, the per-request
# GC.stats are skipped, and stop/transfer return nil. Every consumer
# (RequestTracker, Hijack, Jobs::Base, lograge) is already nil-guarded on that
# path. Restore with DISCOURSE_KEEP_METHOD_PROFILER=1.
if ENV["DISCOURSE_REDUCE_REQUEST_CPU"] == "1" && !ENV["DISCOURSE_KEEP_METHOD_PROFILER"] &&
     defined?(MethodProfiler)
  MethodProfiler.singleton_class.prepend(
    Module.new do
      def start(_transfer = nil)
        nil
      end
    end,
  )
end
