require 'logstash-logger'

class DiscourseLogstashLogger
  def self.logger(uri:, type:)
    LogStashLogger.new(
      uri: uri,
      sync: true,
      customize_event: ->(event) {
        event['hostname'] = `hostname`.chomp
        event['severity'] = Object.const_get("Logger::Severity::#{event['severity']}")
        event['severity_name'] = event['severity']
        event['type'] = type
      },
    )
  end
end
