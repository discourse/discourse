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

    mutex = Mutex.new
    condition_variable = ConditionVariable.new
    test_running = false
    is_waiting = false

    backtrace_logger =
      Thread.new do
        loop do
          mutex.synchronize do
            is_waiting = true
            condition_variable.wait(mutex)
            is_waiting = false
          end

          sleep PER_SPEC_TIMEOUT_SECONDS - 1

          if mutex.synchronize { test_running }
            puts "::group::[#{Process.pid}] Threads backtraces 1 second before timeout"

            Thread.list.each do |thread|
              puts "\n"
              thread.backtrace.each { |line| puts line }
              puts "\n"
            end

            puts "::endgroup::"
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
        mutex.synchronize do
          test_running = true
          condition_variable.signal
        end

        example_procsy.run
      rescue SpecTimeoutError
        puts "--- Potential timeout example ---"
        puts example_procsy.example.metadata
        puts "---"
      ensure
        mutex.synchronize { test_running = false }
        backtrace_logger.wakeup
        sleep 0.01 while !mutex.synchronize { is_waiting }
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
