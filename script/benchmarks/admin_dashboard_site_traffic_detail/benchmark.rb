# frozen_string_literal: true

require "json"
require File.expand_path("../../../config/environment", __dir__)

abort "This benchmark runs only in development." unless Rails.env.development?

class AdminDashboardSiteTrafficDetailBenchmark
  REQUEST_DAYS = 30
  VARIED_FILTERS = [
    { country: "US" },
    { browser: "chrome" },
    { top_url: "/latest" },
    { asn: "AS8075" },
  ].freeze
  private_constant :REQUEST_DAYS, :VARIED_FILTERS

  def initialize
    @cache_keys = []
  end

  def run
    request = build_request(filters: {})
    actor = active_admin
    emit_dataset(request)

    unfiltered_record, =
      measure(label: "cold_unfiltered", request: request) do
        AdminDashboardSiteTrafficDetail.new(request: request).call
      end
    emit(unfiltered_record)

    emit_cached_requests(request: request, actor: actor)
    emit_varied_requests
  ensure
    @cache_keys.each { |cache_key| Discourse.cache.delete(cache_key) }
  end

  private

  def emit_dataset(request)
    eligible_events =
      BrowserPageviewEvent.where(
        created_at:
          request.start_date.beginning_of_day...request.end_date.tomorrow.beginning_of_day,
      )

    emit(
      record: "dataset",
      measured_at: Time.zone.now.iso8601,
      rails_environment: Rails.env,
      configured_event_cap: AdminDashboardSiteTrafficDetail.event_cap,
      requested_start_date: request.start_date.iso8601,
      requested_end_date: request.end_date.iso8601,
      retained_event_count: BrowserPageviewEvent.count,
      eligible_event_count: eligible_events.count,
      eligible_session_count:
        eligible_events.where.not(session_id: [nil, ""]).distinct.count(:session_id),
    )
  end

  def emit_cached_requests(request:, actor:)
    cache_key = unique_cache_key
    computation_count = 0
    computation_lock = Mutex.new
    compute =
      lambda do |cutover_date:, query:|
        computation_lock.synchronize { computation_count += 1 }
        AdminDashboardSiteTrafficDetail.new(request: request).call(cutover_date:, query:)
      end
    ready = Queue.new
    start = Queue.new
    threads =
      2.times.map do |index|
        Thread.new do
          ready << true
          start.pop
          measure(label: "identical_cached_#{index + 1}", request: request) do
            AdminDashboardSiteTrafficDetail::CachedQuery.new(
              request: request,
              actor: actor,
              cache_key: cache_key,
              coordination_key: cache_key,
              compute: compute,
            ).call
          end.first
        end
      end

    threads.size.times { ready.pop }
    threads.size.times { start << true }
    records = threads.map(&:value)

    emit(
      record: "identical_cached_requests",
      computation_count: computation_count,
      requests: records,
    )
  end

  def emit_varied_requests
    requests = VARIED_FILTERS.map { |filters| build_request(filters: filters) }
    ready = Queue.new
    start = Queue.new
    threads =
      requests.each_with_index.map do |request, index|
        Thread.new do
          ready << true
          start.pop
          measure(label: "varied_cold_#{index + 1}", request: request) do
            AdminDashboardSiteTrafficDetail.new(request: request).call
          end.first
        end
      end

    threads.size.times { ready.pop }
    threads.size.times { start << true }

    emit(record: "varied_cold_requests", requests: threads.map(&:value))
  end

  def measure(label:, request:)
    started_at = monotonic_time
    response = yield
    record = {
      record: "request",
      label: label,
      status: "success",
      elapsed_seconds: elapsed_seconds(started_at),
      filter_dimensions: request.filters.keys,
      analyzed_event_count: response.dig(:analysis, :analyzed_event_count),
      pageviews: response.dig(:summary, :pageviews),
      distinct_sessions: response.dig(:summary, :distinct_sessions),
    }
    [record, response]
  rescue AdminDashboardSiteTrafficDetail::Timeout
    [
      {
        record: "request",
        label: label,
        status: "timeout",
        elapsed_seconds: elapsed_seconds(started_at),
        filter_dimensions: request.filters.keys,
        partial_result: false,
      },
      nil,
    ]
  end

  def build_request(filters:)
    AdminDashboardSiteTrafficDetail::Request.parse(
      ActionController::Parameters.new(
        start_date: REQUEST_DAYS.days.ago.to_date.iso8601,
        end_date: Date.current.iso8601,
        filters: filters,
      ),
    )
  end

  def active_admin
    User
      .where(admin: true, active: true)
      .where("suspended_till IS NULL OR suspended_till < ?", Time.zone.now)
      .order(:id)
      .first || abort("The benchmark requires an active admin.")
  end

  def unique_cache_key
    "admin-dashboard-site-traffic-detail-benchmark:#{SecureRandom.hex(16)}".tap do |cache_key|
      @cache_keys << cache_key
      Discourse.cache.delete(cache_key)
    end
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def elapsed_seconds(started_at)
    (monotonic_time - started_at).round(3)
  end

  def emit(record)
    puts JSON.generate(record)
  end
end

AdminDashboardSiteTrafficDetailBenchmark.new.run
