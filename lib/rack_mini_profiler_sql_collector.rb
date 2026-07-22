# frozen_string_literal: true

module RackMiniProfilerSqlCollector
  THREAD_KEY = :rack_mini_profiler_sql_collector
  private_constant :THREAD_KEY

  def self.with_collector(collector)
    previous_collector = Thread.current[THREAD_KEY]
    Thread.current[THREAD_KEY] = collector
    yield
  ensure
    Thread.current[THREAD_KEY] = previous_collector
  end

  def self.current
    Thread.current[THREAD_KEY]
  end

  def self.replay(records)
    records.each(&:replay)
  end

  def self.install!
    SqlPatches.singleton_class.prepend(SqlPatchesPatch)
    Rack::MiniProfiler.singleton_class.prepend(MiniProfilerPatch)
  end

  class Collector
    attr_reader :records

    def initialize
      @records = []
    end

    def capture(query:, elapsed_ms:, params:, cached:)
      Record
        .new(query: query, elapsed_ms: elapsed_ms, params: params, cached: cached)
        .tap { |record| records << record }
    end
  end

  class Record
    def initialize(query:, elapsed_ms:, params:, cached:)
      @query = query
      @elapsed_ms = elapsed_ms
      @params = params
      @cached = cached
      @reader_durations = []
    end

    def report_reader_duration(elapsed_ms, row_count = nil, class_name = nil)
      @reader_durations << [elapsed_ms, row_count, class_name]
    end

    def replay
      replayed_record = Rack::MiniProfiler.record_sql(@query, @elapsed_ms, @params, @cached)
      @reader_durations.each do |elapsed_ms, row_count, class_name|
        replayed_record&.report_reader_duration(elapsed_ms, row_count, class_name)
      end
    end
  end

  module SqlPatchesPatch
    def should_measure?
      !!RackMiniProfilerSqlCollector.current || super
    end
  end

  module MiniProfilerPatch
    def record_sql(query, elapsed_ms, params = nil, cached = nil)
      if collector = RackMiniProfilerSqlCollector.current
        collector.capture(query: query, elapsed_ms: elapsed_ms, params: params, cached: cached)
      else
        super
      end
    end
  end
end

RackMiniProfilerSqlCollector.install!
