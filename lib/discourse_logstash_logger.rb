# frozen_string_literal: true

require 'logstash-logger'

class DiscourseLogstashLogger
  def self.logger(uri:, type:)
    # See Discourse.os_hostname
    hostname = begin
      require 'socket'
      Socket.gethostname
    rescue => e
      `hostname`.chomp
    end

    LogStashLogger.new(
      uri: uri,
      sync: true,
      customize_event: ->(event) {
        event['hostname'] = hostname
        event['severity_name'] = event['severity']
        event['severity'] = Object.const_get("Logger::Severity::#{event['severity']}")
        event['type'] = type
        event['pid'] = Process.pid
      },
    )
  end
end
