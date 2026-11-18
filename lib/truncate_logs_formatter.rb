# frozen_string_literal: true

# This log formatter limits the number of characters in each log message to prevent malicious requests from filling up the disk
# in a short amount of time. The number of characters is determined by the `log_line_max_chars` global setting which can be
# configured via the `DISCOURSE_LOG_LINE_MAX_CHARS` environment variable.
class TruncateLogsFormatter < ::ActiveSupport::Logger::SimpleFormatter
  include ::ActiveSupport::TaggedLogging::Formatter

  def initialize(log_line_max_chars:)
    @log_line_max_chars = log_line_max_chars
  end

  def call(*args)
    # Lograge formatters are only called with a single argument instead of the usual 4 arguments of `severity`, `datetime`, `progname` and `message`.
    message =
      if args.length == 1
        args[0]
      else
        args[3]
      end

    self.class.truncate(message, max_chars: @log_line_max_chars)
  end

  def self.truncate(message, max_chars:)
    if message.length > max_chars
      newlines = message.length - message.chomp.length
      "#{message[0, max_chars]}...(truncated)#{"\n" * newlines}"
    else
      message
    end
  end
end
