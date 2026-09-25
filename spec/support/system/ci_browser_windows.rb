# frozen_string_literal: true
require "json"
require "timeout"

class CiBrowserWindows
  WINDOWS = { 5 => "early", 100 => "later" }.freeze
  CATEGORY_NAMES = {
    "compile" => %w[v8.compile v8.compileModule V8.CompileCode V8.CompileModule],
    "module_execute" => %w[EvaluateModule v8.evaluateModule],
    "script" => %w[FunctionCall EvaluateScript RunMicrotasks V8.Execute],
    "browser_render" => %w[UpdateLayoutTree Layout PrePaint Paint CompositeLayers Layerize],
    "style" => %w[UpdateLayoutTree ParseAuthorStyleSheet RecalculateStyles],
    "layout" => %w[Layout],
    "gc" => %w[MinorGC MajorGC V8.GCScavenger V8.GCCompactor V8.GCFinalizeMC],
    "parse_html" => %w[ParseHTML],
  }.freeze
  TASK_EVENT_NAMES = %w[ThreadPool_RunTask ThreadControllerImpl::RunTask].freeze
  TASK_SOURCES = {
    "third_party/blink/renderer/bindings/core/v8/script_streamer.cc" => "script_streaming",
    "third_party/blink/renderer/bindings/core/v8/script_decoder.cc" => "script_decoding",
    "v8/src/maglev/maglev-concurrent-dispatcher.cc" => "maglev_compile",
    "v8/src/baseline/baseline-batch-compiler.cc" => "baseline_compile",
    "v8/src/compiler-dispatcher/optimizing-compile-dispatcher.cc" => "optimizing_compile",
    "v8/src/heap/scavenger.cc" => "gc_scavenge",
    "v8/src/heap/concurrent-marking.cc" => "gc_mark",
    "cc/raster/categorized_worker_pool.cc" => "categorized_worker_pool",
    "third_party/blink/renderer/core/script/html_parser_script_runner.cc" => "html_script_runner",
    "third_party/blink/renderer/core/html/parser/html_document_parser.cc" => "html_parser",
    "ipc/ipc_mojo_bootstrap.cc" => "ipc_mojo",
  }.freeze
  TASK_GROUPS = (TASK_SOURCES.values + ["other_task"]).freeze
  SAFE_EVENT_NAMES =
    (CATEGORY_NAMES.values.flatten + TASK_EVENT_NAMES).to_h { |name| [name, name.freeze] }.freeze
  SAFE_PHASES = %w[B E X M].to_h { |phase| [phase, phase.freeze] }.freeze
  TIMING_FIELDS = %w[ts dur tts tdur].each(&:freeze).freeze
  MAX_EVENT_ROWS = 200_000
  private_constant :WINDOWS,
                   :CATEGORY_NAMES,
                   :TASK_EVENT_NAMES,
                   :TASK_SOURCES,
                   :TASK_GROUPS,
                   :SAFE_EVENT_NAMES,
                   :SAFE_PHASES,
                   :TIMING_FIELDS,
                   :MAX_EVENT_ROWS

  def initialize
    @process_id = Process.pid
    @example_count = 0
    @emitted = []
    @disabled = false
    @window = @browser = @session = @completion = nil
  end

  def run
    initialize if @process_id != Process.pid
    @example_count += 1
    start_window(WINDOWS[@example_count]) if !@disabled && WINDOWS.key?(@example_count)
    yield
  ensure
    if @window
      @window[:sample_count] += 1
      finish_window if @window[:sample_count] >= 3 || elapsed >= 30 || @window[:reason]
    end
  end

  def observe(browser_page)
    return if @disabled

    browser = browser_page.context.browser
    if @window && (!browser.equal?(@browser) || !browser.connected?)
      @window[:reason] = "browser_changed_or_disconnected"
    elsif !@window
      @browser = browser
    end
  rescue StandardError
    @window[:reason] = "browser_observation_failed" if @window
    @browser = nil unless @window
  end

  def self.sanitize_event(event)
    phase = SAFE_PHASES[event["ph"]]
    return unless phase
    return unless event["pid"].is_a?(Integer) && event["tid"].is_a?(Integer)

    row = { "ph" => phase, "pid" => event["pid"], "tid" => event["tid"] }
    if phase == "M"
      case event["name"]
      when "process_name"
        row["name"] = "process_name"
        name = %w[Renderer Browser Gpu].find { |value| value == event.dig("args", "name") }
        name = "Gpu" if event.dig("args", "name") == "GPU Process"
      when "thread_name"
        row["name"] = "thread_name"
        name = "CrRendererMain" if event.dig("args", "name") == "CrRendererMain"
      else
        return
      end
      row["args"] = { "name" => name || "other" }
    else
      row["name"] = SAFE_EVENT_NAMES.fetch(event["name"], "other")
      if TASK_EVENT_NAMES.include?(row["name"])
        source = event.dig("args", "src_file")
        source = source.sub(%r{\A(?:\.\.?/)+}, "") if source.is_a?(String)
        row["task_origin"] = TASK_SOURCES.fetch(source, "other_task")
      end
      TIMING_FIELDS.each { |key| row[key] = event[key] if finite_number?(event[key]) }
    end
    row
  end

  def finish_suite
    if @window
      @window[:reason] ||= "suite_ended"
      finish_window
    end
    WINDOWS.each_value do |label|
      next if @emitted.include?(label)

      reason = @disabled ? "previous_window_collection_failed" : "window_not_reached"
      emit(window: label, status: "invalid", reason: reason, sample_count: 0)
    end
  end

  def self.aggregate(events)
    process_names = {}
    thread_names = {}
    events.each do |event|
      next unless event["ph"] == "M"

      if event["name"] == "process_name"
        process_names[event["pid"]] = event.dig("args", "name")
      elsif event["name"] == "thread_name"
        thread_names[[event["pid"], event["tid"]]] = event.dig("args", "name")
      end
    end

    intervals =
      Hash.new { |groups, label| groups[label] = Hash.new { |threads, key| threads[key] = [] } }
    counts = {
      duration_event_count: 0,
      cpu_event_count: 0,
      missing_cpu_timestamp_count: 0,
      invalid_duration_count: 0,
      unmatched_begin_end_count: 0,
    }
    stacks = Hash.new { |threads, key| threads[key] = [] }
    events.each do |event|
      key = [event["pid"], event["tid"]]
      case event["ph"]
      when "B"
        stacks[key] << event
        next
      when "E"
        beginning = stacks[key].pop
        unless beginning
          counts[:unmatched_begin_end_count] += 1
          next
        end
        event =
          beginning.merge(
            "dur" => difference(start: beginning["ts"], finish: event["ts"]),
            "tdur" => difference(start: beginning["tts"], finish: event["tts"]),
          )
      when "X"
      else
        next
      end
      counts[:duration_event_count] += 1
      unless finite_number?(event["dur"]) && event["dur"] >= 0
        counts[:invalid_duration_count] += 1
        next
      end
      unless finite_number?(event["tts"]) && finite_number?(event["tdur"]) && event["tdur"] >= 0
        counts[:missing_cpu_timestamp_count] += 1
        next
      end
      counts[:cpu_event_count] += 1
      interval = [event["tts"], event["tts"] + event["tdur"]]
      process =
        case process_names[event["pid"]]
        when "Renderer"
          "renderer"
        when "Browser"
          "browser"
        when "GPU Process", "Gpu"
          "gpu"
        else
          "other"
        end
      intervals["process_#{process}"][key] << interval
      if process == "renderer"
        thread = thread_names[key] == "CrRendererMain" ? "main" : "helper"
        intervals["renderer_#{thread}"][key] << interval
        if TASK_EVENT_NAMES.include?(event["name"])
          origin = TASK_GROUPS.include?(event["task_origin"]) ? event["task_origin"] : "other_task"
          intervals["renderer_#{thread}_tasks"][key] << interval
          intervals["task_#{thread}_#{origin}"][key] << interval
        end
      end
      CATEGORY_NAMES.each do |label, names|
        intervals["category_#{label}"][key] << interval if names.include?(event["name"])
      end
    end
    counts[:unmatched_begin_end_count] += stacks.values.sum(&:length)
    {
      **counts,
      process_cpu_seconds:
        %w[renderer browser gpu other].to_h do |label|
          [label, union_seconds(intervals["process_#{label}"])]
        end,
      renderer_thread_cpu_seconds:
        %w[main helper].to_h { |label| [label, union_seconds(intervals["renderer_#{label}"])] },
      nonadditive_category_cpu_seconds:
        CATEGORY_NAMES.keys.to_h { |label| [label, union_seconds(intervals["category_#{label}"])] },
      renderer_task_cpu_seconds:
        %w[main helper].to_h do |thread|
          [thread, union_seconds(intervals["renderer_#{thread}_tasks"])]
        end,
      nonadditive_renderer_task_origin_cpu_seconds:
        %w[main helper].to_h do |thread|
          [
            thread,
            TASK_GROUPS.to_h do |origin|
              [origin, union_seconds(intervals["task_#{thread}_#{origin}"])]
            end,
          ]
        end,
      task_origin_semantics: "posting_location_not_leaf_execution",
      cpu_coverage: "available_thread_timestamps_only",
    }
  end

  class << self
    private

    def finite_number?(value)
      value.is_a?(Numeric) && value.finite?
    end

    def difference(start:, finish:)
      finish - start if finite_number?(start) && finite_number?(finish)
    end

    def union_seconds(threads)
      total =
        threads.values.sum do |intervals|
          covered_until = -Float::INFINITY
          intervals.sort.sum do |start, finish|
            added = [finish - [start, covered_until].max, 0].max
            covered_until = [covered_until, finish].max
            added
          end
        end
      (total / 1_000_000.0).round(6)
    end
  end

  private

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def elapsed
    monotonic - @window[:started]
  end

  def start_window(label)
    started = monotonic
    @window = {
      window: label,
      sample_count: 0,
      started: started,
      collection_seconds: 0,
      filter_seconds: 0,
      buffer_usage_max: 0,
      buffer_event_count_max: 0,
      buffer_usage_report_count: 0,
      data_loss: nil,
      rows: [],
      received_event_count: 0,
      dropped_event_count: 0,
      accept_events: true,
    }
    @completion = Queue.new
    @session = nil
    window = @window
    completion = @completion
    Timeout.timeout(3) do
      unless @browser&.connected?
        @window[:reason] = "browser_unavailable"
        return
      end
      @session = @browser.new_browser_cdp_session
      @session.on(
        "Tracing.tracingComplete",
        ->(event) { completion << !!event["dataLossOccurred"] },
      )
      @session.on(
        "Tracing.dataCollected",
        ->(event) { collect_events(window: window, events: event["value"]) },
      )
      @session.on(
        "Tracing.bufferUsage",
        lambda do |event|
          window[:buffer_usage_report_count] += 1
          %w[percentFull value].each do |key|
            value = event[key]
            if value.is_a?(Numeric) && value.finite?
              window[:buffer_usage_max] = [window[:buffer_usage_max], value].max
            end
          end
          count = event["eventCount"]
          if count.is_a?(Numeric) && count.finite?
            window[:buffer_event_count_max] = [window[:buffer_event_count_max], count].max
          end
        end,
      )
      @session.send_message(
        "Tracing.start",
        params: {
          transferMode: "ReportEvents",
          bufferUsageReportingInterval: 1000,
          traceConfig: {
            includedCategories: %w[toplevel devtools.timeline v8],
            recordMode: "recordUntilFull",
            traceBufferSizeInKb: 16_384,
            enableSampling: false,
          },
        },
      )
    end
  rescue StandardError
    @window[:reason] = "trace_start_failed"
  ensure
    @window[:collection_seconds] += monotonic - started
    @window[:started] = monotonic
  end

  def collect_events(window:, events:)
    return unless window[:accept_events]

    started = monotonic
    window[:received_event_count] += events.length
    events.each_with_index do |event, index|
      if window[:rows].length >= MAX_EVENT_ROWS
        window[:dropped_event_count] += events.length - index
        window[:reason] ||= "event_row_limit"
        break
      end
      row = self.class.sanitize_event(event)
      window[:rows] << row if row
    end
  rescue StandardError
    window[:reason] ||= "event_filter_failed"
  ensure
    window[:filter_seconds] += monotonic - started if started
  end

  def finish_window
    wall_seconds = elapsed
    collection_started = monotonic
    aggregate = nil
    trace_ended = false
    completion_received = false
    begin
      Timeout.timeout(10) do
        if @session
          @session.send_message("Tracing.end")
          trace_ended = true
          @window[:data_loss] = @completion.pop
          completion_received = true
          @window[:accept_events] = false
          @window[:reason] ||= "data_loss" if @window[:data_loss]
          @window[:reason] ||= "buffer_saturated" if @window[:buffer_usage_max] >= 1
          unless @window[:reason]
            aggregate = self.class.aggregate(@window[:rows])
            @window[:reason] = "cpu_timestamps_missing" if aggregate[:cpu_event_count] == 0
          end
        end
      end
    rescue Timeout::Error
      @disabled = true
      @window[:reason] ||= "collection_timeout"
    rescue StandardError
      @disabled = true
      @window[:reason] ||= "browser_or_session_closed"
    ensure
      @window[:accept_events] = false
      begin
        Timeout.timeout(2) { @session.send_message("Tracing.end") } if @session && !trace_ended
      rescue StandardError
        @disabled = true
        @window[:reason] ||= "trace_cleanup_failed"
      end
      begin
        Timeout.timeout(2) { @session.detach } if @session
      rescue StandardError
        @disabled = true
        @window[:reason] ||= "session_detach_failed"
      end
      @window[:collection_seconds] += monotonic - collection_started
      result = {
        window: @window[:window],
        status: @window[:reason] ? "invalid" : "ok",
        reason: @window[:reason],
        sample_count: @window[:sample_count],
        sample_limit: 3,
        wall_seconds: wall_seconds.round(6),
        elapsed_limit_seconds: 30,
        elapsed_limit_check: "between_examples",
        elapsed_limit_exceeded: wall_seconds > 30,
        profiler_collection_seconds: @window[:collection_seconds].round(6),
        event_filter_seconds: @window[:filter_seconds].round(6),
        data_loss: @window[:data_loss],
        buffer_usage_max: @window[:buffer_usage_max],
        buffer_event_count_max: @window[:buffer_event_count_max],
        buffer_usage_report_count: @window[:buffer_usage_report_count],
        saturated: @window[:buffer_usage_max] >= 1,
        received_event_count: @window[:received_event_count],
        retained_event_count: @window[:rows].length,
        dropped_event_count: @window[:dropped_event_count],
        event_row_limit: MAX_EVENT_ROWS,
        trace_completion_received: completion_received,
        trace_completion_unconfirmed: !!(@session && !completion_received),
        remaining_windows_disabled: !!@disabled,
      }
      result.merge!(aggregate) if aggregate && !@window[:reason]
      @window[:rows].clear
      @window = @session = @completion = nil
      emit(result)
    end
  end

  def emit(result)
    @emitted << result[:window]
    worker = ENV.fetch("TEST_ENV_NUMBER", "")
    worker =
      if worker.empty?
        1
      elsif worker.match?(/\A[1-9][0-9]?\z/) && worker.to_i <= 64
        worker.to_i
      else
        "other"
      end
    puts "CI_BROWSER_WINDOW #{JSON.generate(result.merge(worker: worker))}"
  rescue StandardError
    nil
  end
end

if defined?(RSpec) && ENV["DISCOURSE_CI_BROWSER_PROFILE"] == "1"
  windows = CiBrowserWindows.new
  tracking =
    Module.new do
      define_method(:new_page) do
        browser_page = super()
        windows.observe(browser_page)
        browser_page
      end
    end
  RSpec.configure do |config|
    config.around(:each, type: :system) { |example| windows.run { example.run } }
    config.before(:suite) { Playwright::BrowserContext.prepend(tracking) }
    config.after(:suite) { windows.finish_suite }
  end
end
