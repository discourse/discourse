# frozen_string_literal: true

# CI-only instrumentation: GitHub Actions output, a per-spec timeout that dumps
# thread backtraces, a Capybara localhost-resolution retry, and optional
# per-example profiling / ActiveRecord query logging.

PER_SPEC_TIMEOUT_SECONDS = 45

RSpec.configure do |config|
  if ENV["GITHUB_ACTIONS"]
    # Enable color output in GitHub Actions
    # This eventually will be `config.color_mode = :on` in RSpec 4?
    config.tty = true
    config.color = true
  end

  if ENV["CI"]
    class SpecTimeoutError < StandardError
    end

    # A single watchdog thread polls a shared monotonic deadline on a fixed 1s
    # cadence and dumps every thread's backtrace when the running example is
    # within ~1s of the PER_SPEC_TIMEOUT_SECONDS hard limit (which the
    # `Timeout.timeout` below still enforces independently). This replaces a
    # mutex / condition-variable handshake whose `config.around` `ensure` ran,
    # after EVERY example, `sleep 0.01 while !is_waiting` to re-arm the logger
    # thread — a guaranteed >=10ms spin-wait (plus several mutex round-trips and
    # a `Thread#wakeup`) on the example thread, on the critical path *between*
    # every one of the ~170 examples each of the 12 parallel system-test workers
    # runs. That is ~1.7s of dead main-thread time per worker, and its
    # scheduling latency under the saturated 16-core runner inflated the tail.
    # The poll-based watchdog needs no per-example coordination, so the around
    # hook drops to two plain local-variable writes and that between-examples
    # stall disappears. `running`/`deadline_monotonic` are shared via the
    # closure binding; MRI's GVL makes the plain reads/writes safe across the
    # two threads.
    running = false
    deadline_monotonic = nil

    Thread.new do
      loop do
        sleep 1

        deadline = deadline_monotonic
        if running && deadline &&
             Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline - 1
          puts "::group::[#{Process.pid}] Threads backtraces ~1 second before timeout"

          Thread.list.each do |thread|
            puts "\n"
            (thread.backtrace || []).each { |line| puts line }
            puts "\n"
          end

          puts "::endgroup::"

          # Don't re-dump on every subsequent 1s tick for the same stuck
          # example; the next example resets the deadline.
          deadline_monotonic = nil
        end
      rescue StandardError => e
        puts "Error in backtrace logger: #{e}"
      end
    end

    config.around do |example_procsy|
      Timeout.timeout(
        PER_SPEC_TIMEOUT_SECONDS,
        SpecTimeoutError,
        "Spec timed out after #{PER_SPEC_TIMEOUT_SECONDS} seconds",
      ) do
        deadline_monotonic =
          Process.clock_gettime(Process::CLOCK_MONOTONIC) + PER_SPEC_TIMEOUT_SECONDS
        running = true

        example_procsy.run
      rescue SpecTimeoutError
        puts "--- Potential timeout example ---"
        puts example_procsy.example.metadata
        puts "---"
      ensure
        running = false
      end
    end

    # This is a monkey patch for the `Capybara.using_session` method in `capybara`. For some
    # unknown reasons on Github Actions, we are seeing system tests failing intermittently with the error
    # `Socket::ResolutionError: getaddrinfo: Temporary failure in name resolution` when the app tries to resolve
    # `localhost` from within a `Capybara#using_session` block.
    #
    # Too much time has been spent trying to debug this issue and the root cause is still unknown so we are just dropping
    # this workaround for now where we will retry the block once before raising the error.
    #
    # Potentially related: https://bugs.ruby-lang.org/issues/20172
    module Capybara
      class << self
        def using_session_with_localhost_resolution(name, &block)
          attempts = 0
          _using_session(name, &block)
        rescue Socket::ResolutionError
          puts "Socket::ResolutionError error encountered... Current thread count: #{Thread.list.size}"
          attempts += 1
          attempts <= 1 ? retry : raise
        end
      end
    end

    Capybara.singleton_class.class_eval do
      alias_method :_using_session, :using_session
      alias_method :using_session, :using_session_with_localhost_resolution
    end
  end

  if ENV["DISCOURSE_RSPEC_PROFILE_EACH_EXAMPLE"]
    config.around :each do |example|
      measurement = Benchmark.measure { example.run }
      RSpec.current_example.metadata[:run_duration_ms] = (measurement.real * 1000).round(2)
    end
  end

  if ENV["GITHUB_ACTIONS"]
    config.around :each, capture_log: true do |example|
      original_logger = ActiveRecord::Base.logger
      io = StringIO.new
      io_logger = Logger.new(io)
      io_logger.level = Logger::DEBUG
      ActiveRecord::Base.logger = io_logger

      example.run

      RSpec.current_example.metadata[:active_record_debug_logs] = io.string
    ensure
      ActiveRecord::Base.logger = original_logger
    end
  end
end

if ENV["CI"]
  # With `mini_racer_single_threaded = true` (the default), every
  # `PrettyText.protect` block and `AssetProcessor.v8_call` ends with
  # `Context#low_memory_notification` — a forced full V8 GC intended to keep
  # long-lived production processes compact. In short-lived CI spec workers
  # that compaction buys nothing while costing a full collection on every
  # markdown cook (measured: 8.83ms -> 3.27ms per cook without it) and ~50
  # forced GCs during each worker's `PrettyText.create_es6_context` transpile
  # (~1.5s per worker). V8's own allocation-triggered GC still runs; only the
  # redundant forced collection is dropped.
  MiniRacer::Context.prepend(
    Module.new do
      def low_memory_notification
      end
    end,
  )
end
