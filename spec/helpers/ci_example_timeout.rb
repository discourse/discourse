# frozen_string_literal: true

require "timeout"

class SpecTimeoutError < StandardError
end

class CiExampleTimeout
  def self.install(config, seconds:)
    watchdog = nil
    config.before(:suite) { watchdog = CiExampleTimeout.new(seconds) }
    config.after(:suite) { watchdog&.stop }

    config.around do |example|
      watchdog.run { example.run }
    rescue SpecTimeoutError
      timed_out = true
      raise
    ensure
      # RSpec usually records an exception raised in the example instead of re-raising it.
      if timed_out || example.exception.is_a?(SpecTimeoutError)
        puts "--- Potential timeout example ---", example.metadata, "---"
      end
    end
  end

  def initialize(seconds)
    @seconds = seconds
    # Some examples stub Process.clock_gettime or freeze wall time.
    @clock_gettime = Process.method(:clock_gettime)
    @mutex = Mutex.new
    @changed = ConditionVariable.new
    @logger = Thread.new { log_timeouts }
    @logger.name = "RSpec timeout backtraces"
  end

  def run(&block)
    set_deadline(monotonic_now + @seconds - 1)
    Timeout.timeout(@seconds, SpecTimeoutError, "Spec timed out after #{@seconds} seconds", &block)
  ensure
    set_deadline(nil)
  end

  def stop
    @mutex.synchronize do
      @stopped = true
      @changed.signal
    end
    @logger.join
  end

  private

  def monotonic_now
    @clock_gettime.call(Process::CLOCK_MONOTONIC)
  end

  def set_deadline(deadline)
    @mutex.synchronize do
      @deadline = deadline
      @changed.signal
    end
  end

  def wait_for_backtraces
    @mutex.synchronize do
      until @stopped
        # An entire example can finish and another start before the logger wakes.
        remaining = @deadline && @deadline - monotonic_now
        if remaining && remaining <= 0
          @deadline = nil
          # Snapshot before the next example can start; write to stdout outside the lock.
          return Thread.list.filter_map(&:backtrace)
        end
        @changed.wait(@mutex, remaining)
      end
    end
    nil
  end

  def log_timeouts
    loop do
      backtraces = wait_for_backtraces
      break unless backtraces

      puts "::group::[#{Process.pid}] Threads backtraces 1 second before timeout"
      begin
        backtraces.each { |backtrace| puts "", backtrace, "" }
      ensure
        puts "::endgroup::"
      end
    rescue StandardError => e
      puts "Error in backtrace logger: #{e}"
    end
  end
end
