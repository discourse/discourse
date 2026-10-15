# frozen_string_literal: true
require "json"

module DirectMeasurementRetryAudit
  ROWS = []

  def self.record(row)
    ROWS << row
    warn "DIRECT_MEASUREMENT_RETRY=#{JSON.generate(row)}"
  end

  def flush!(session, timeout:)
    DirectMeasurementRetryAudit.record(
      example: RSpec.current_example&.full_description,
      recovery: "MessageBus matcher timeout",
    )
    super
  end
end

module DirectNativeMatcherTimeoutAudit
  private

  def call_assertion(actual, is_not)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    super
  rescue Playwright::AssertionError
    elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    timeout_ms = @kwargs.fetch(:timeout, Playwright::Test.expect_timeout)
    if timeout_ms && timeout_ms.positive? && elapsed_seconds >= timeout_ms / 1000.0 * 0.95
      DirectMeasurementRetryAudit.record(
        example: RSpec.current_example&.full_description,
        recovery: "Native matcher reached full wait",
        elapsed_seconds: elapsed_seconds,
        timeout_ms: timeout_ms,
        matcher: @method,
        negated: is_not,
        source:
          caller_locations
            .filter_map do |location|
              "#{location.path}:#{location.lineno}" if location.path.include?("/spec/")
            end
            .first(4),
      )
    end
    raise
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    MessageBusTestSync.singleton_class.prepend(DirectMeasurementRetryAudit)
    if defined?(Playwright::Test::Matchers::PlaywrightMatcher)
      Playwright::Test::Matchers::PlaywrightMatcher.prepend(DirectNativeMatcherTimeoutAudit)
    end
  end

  config.after(:suite) do
    puts "DIRECT_MEASUREMENT_RETRY_AUDIT=#{JSON.generate({ count: DirectMeasurementRetryAudit::ROWS.length, recoveries: DirectMeasurementRetryAudit::ROWS })}"
  end
end
