# frozen_string_literal: true

# Capturing and silencing log/stdout output in specs.

module LoggingHelpers
  def silence_stdout
    STDOUT.stubs(:write)
    yield
  ensure
    STDOUT.unstub(:write)
  end

  def track_log_messages
    logger = FakeLogger.new
    Rails.logger.broadcast_to(logger)
    yield logger
    logger
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end

# Block direct assignment to Rails.logger in tests; use `track_log_messages` instead.
def Rails.logger=(logger)
  raise "Setting Rails.logger is not allowed as it can lead to unexpected behavior in tests. Use `fake_logger = track_log_messages { ... }` instead."
end
