# frozen_string_literal: true

require 'logstash-logger'

class DiscourseLogstashLogger
  def self.logger(uri:, type:)
    LogStashLogger.new(
      uri: uri,
      sync: true,
      customize_event: ->(event) {
        event['hostname'] = `hostname`.chomp
        event['severity_name'] = event['severity']
        event['severity'] = Object.const_get("Logger::Severity::#{event['severity']}")
        event['type'] = type
        event['pid'] = Process.pid
      },
    )
  end
end
