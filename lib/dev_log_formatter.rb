# frozen_string_literal: true

# Compact dev log formatter: drops timestamp and pid.
# Prefixes a severity label for file log, drops the prefix
# applies color to the whole message instead.
class DevLogFormatter < ::Logger::Formatter
  SEVERITY_COLORS = {
    "DEBUG" => "\e[90m",
    "WARN" => "\e[33m",
    "ERROR" => "\e[31m",
    "FATAL" => "\e[1;31m",
    "UNKNOWN" => "\e[35m",
  }.freeze
  RESET = "\e[0m"

  attr_reader :color

  def initialize(color: false)
    super()
    @color = color
  end

  def colored
    clone.tap { |f| f.instance_variable_set(:@color, true) }
  end

  def call(severity, _time, _progname, msg)
    message = msg2str(msg)
    if @color
      code = SEVERITY_COLORS[severity]
      code ? "#{code}#{message}#{RESET}\n" : "#{message}\n"
    else
      "#{severity.ljust(5)}  #{message}\n"
    end
  end
end
