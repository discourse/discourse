require 'json'

class UnicornJSONLogFormatter < Logger::Formatter
  def call(severity, datetime, progname, message)
    default = {
      severity: severity,
      datetime: datetime,
      progname: progname || '',
      pid: $$,
    }

    default[:message] =
      if message.is_a?(Exception)
        "#{message.message}: #{message.backtrace.join("\n")}"
      else
        message
      end

    "#{default.to_json}\n"
  end
end
