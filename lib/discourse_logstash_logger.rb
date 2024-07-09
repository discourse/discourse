# frozen_string_literal: true

require "json"
require "socket"

class DiscourseLogstashLogger < Logger
  PROCESS_PID = Process.pid
  HOST = Socket.gethostname

  attr_accessor :customize_event, :type

  # Creates a new logger instance.
  #
  # @param logdev [String, IO, nil] The log device. This can be one of:
  #   - A string filepath: entries are written to the file at that path. If the file exists, new entries are appended.
  #   - An IO stream (typically +$stdout+, +$stderr+, or an open file): entries are written to the given stream.
  #   - nil or File::NULL: no entries are written.
  # @param type [String] The type of log messages. This will add a `type` field to all log messages.
  # @param customize_event [Proc, nil] A proc that customizes the log event before it is written to the log device.
  #   The proc is called with a hash of log event data and can be modified in place.
  #
  # @return [Logger] A new logger instance with the specified log device and type.
  def self.logger(logdev:, type:, customize_event: nil)
    logger = self.new(logdev)
    logger.type = type
    logger.customize_event = customize_event if customize_event
    logger
  end

  # :nodoc:
  def add(*args, &block)
    add_with_opts(*args, &block)
  end

  ALLOWED_HEADERS_FROM_ENV = %w[
    REQUEST_URI
    REQUEST_METHOD
    HTTP_HOST
    HTTP_USER_AGENT
    HTTP_ACCEPT
    HTTP_REFERER
    HTTP_X_FORWARDED_FOR
    HTTP_X_REAL_IP
  ]

  # :nodoc:
  def add_with_opts(severity, message = nil, progname = nil, opts = {}, &block)
    return true if @logdev.nil? || severity < @level

    progname = @progname if progname.nil?

    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end

    event = {
      "message" => message.to_s,
      "severity" => severity,
      "severity_name" => Logger::SEV_LABEL[severity],
      "pid" => PROCESS_PID,
      "type" => @type.to_s,
      "host" => HOST,
    }

    # Only log backtrace and env for Logger::WARN and above.
    # Backtrace is just noise for anything below that.
    if severity >= Logger::WARN
      if (backtrace = opts&.dig(:backtrace)).present?
        event["backtrace"] = backtrace
      end

      if (env = opts&.dig(:env)).present?
        ALLOWED_HEADERS_FROM_ENV.each do |header|
          event["request.headers.#{header.downcase}"] = opts[:env][header]
        end
      end
    end

    if message.is_a?(String) && message.start_with?("{") && message.end_with?("}")
      begin
        parsed = JSON.parse(message)
        event["message"] = parsed.delete("message") if parsed["message"]
        event.merge!(parsed)
        event
      rescue JSON::ParserError
        # Do nothing
      end
    end

    @customize_event.call(event) if @customize_event

    @logdev.write("#{event.to_json}\n")
  rescue Exception => e
    STDERR.puts "Error logging message `#{message}` in DiscourseLogstashLogger: #{e.class} (#{e.message})\n#{e.backtrace.join("\n")}"
  end
end
