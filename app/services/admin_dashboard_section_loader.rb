# frozen_string_literal: true

class AdminDashboardSectionLoader
  def self.build(section_ids:, current_user:, start_date:, end_date:, parallel: true)
    new(
      section_ids: section_ids,
      current_user: current_user,
      start_date: start_date,
      end_date: end_date,
      parallel: parallel,
    ).build
  end

  def self.pool_size
    desired =
      AdminDashboardSectionConfiguration::KNOWN_SECTIONS.size +
        DiscoursePluginRegistry.admin_dashboard_sections.size

    available = [ActiveRecord::Base.connection_pool.size - 1, 1].max
    [desired, available].min
  end

  def self.thread_pool
    @thread_pool ||=
      Scheduler::ThreadPool.new(min_threads: 0, max_threads: pool_size, idle_time: 30)
  end

  def initialize(section_ids:, current_user:, start_date:, end_date:, parallel: true)
    @section_ids = section_ids
    @current_user = current_user
    @start_date = start_date
    @end_date = end_date
    @parallel = parallel
  end

  def build
    if parallel
      build_in_parallel
    else
      section_ids.map { |id| build_section(id) }
    end
  end

  private

  attr_reader :section_ids, :current_user, :start_date, :end_date, :parallel

  def build_in_parallel
    results = Queue.new
    collect_sql = collect_worker_sql?

    section_ids.each do |id|
      self.class.thread_pool.post { results << build_worker_section(id, collect_sql: collect_sql) }
    end

    results_by_id = {}

    section_ids.size.times do
      result = results.pop
      RackMiniProfilerSqlCollector.replay(result[:sql_timings]) if result[:sql_timings]
      results_by_id[result[:id]] = normalize_result(result)
    end

    section_ids.map { |id| results_by_id.fetch(id) }
  end

  def build_worker_section(id, collect_sql:)
    records = nil
    result = nil

    ActiveRecord::Base.with_connection(prevent_permanent_checkout: true) do
      if collect_sql
        collector = RackMiniProfilerSqlCollector::Collector.new
        records = collector.records
        RackMiniProfilerSqlCollector.with_collector(collector) { result = raw_section_result(id) }
      else
        result = raw_section_result(id)
      end
    end

    result.merge(sql_timings: records)
  rescue StandardError => error
    { id: id, error: error, sql_timings: records }
  end

  def build_section(id)
    normalize_result(raw_section_result(id))
  rescue StandardError => error
    normalize_result(id: id, error: error)
  end

  def raw_section_result(id)
    { id: id, data: section_data(id, current_user) }
  end

  def normalize_result(result)
    return result.except(:sql_timings) if !result[:error]

    Discourse.warn_exception(
      result[:error],
      message: "Failed to build admin dashboard section",
      env: {
        section_id: result[:id],
      },
    )

    { id: result[:id], data: nil, error: true }
  end

  def collect_worker_sql?
    defined?(RackMiniProfilerSqlCollector) && defined?(Rack::MiniProfiler) &&
      Rack::MiniProfiler.current&.measure
  end

  def section_data(id, user)
    case id
    when "highlights"
      AdminDashboardHighlights.build(start_date: start_date, end_date: end_date)
    when "traffic"
      AdminDashboardSiteTraffic.build(
        start_date: start_date,
        end_date: end_date,
        guardian: user.guardian,
      )
    when "engagement"
      AdminDashboardEngagement.build(start_date: start_date, end_date: end_date, current_user: user)
    when "reports"
      AdminDashboard::Reports::Section.build(guardian: user.guardian)
    when "search"
      AdminDashboardSearch.build(start_date: start_date, end_date: end_date)
    else
      section = DiscoursePluginRegistry.admin_dashboard_sections.find { |s| s[:id] == id }
      section&.dig(:loader)&.call(start_date: start_date, end_date: end_date, current_user: user)
    end
  end
end
