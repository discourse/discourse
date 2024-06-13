# frozen_string_literal: true

require "logstash-logger"

class DiscourseLogstashLogger
  def self.hostname
    @hostname ||=
      begin
        require "socket"
        Socket.gethostname
      rescue => e
        `hostname`.chomp
      end
  end

  def self.logger(uri:, type:)
    LogStashLogger.new(
      uri: uri,
      sync: true,
      customize_event: ->(event) do
        event["hostname"] = self.hostname
        event["severity_name"] = event["severity"]
        event["severity"] = Object.const_get("Logger::Severity::#{event["severity"]}")
        event["type"] = type
        event["pid"] = Process.pid
      end,
    )
  end
end
