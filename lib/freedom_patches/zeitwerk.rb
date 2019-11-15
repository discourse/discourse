# frozen_string_literal: true

module ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector
  CUSTOM_PATHS = {
    'canonical_url' => 'CanonicalURL',
    'clean_up_unmatched_ips' => 'CleanUpUnmatchedIPs',
    'homepage_constraint' => 'HomePageConstraint',
    'ip_addr' => 'IPAddr',
    'onpdiff' => 'ONPDiff',
    'onceoff' => 'Jobs',
    'pop3_polling_enabled_setting_validator' => 'POP3PollingEnabledSettingValidator',
    'postgresql_fallback_adapter' => 'PostgreSQLFallbackHandler',
    'regular' => 'Jobs',
    'scheduled' => 'Jobs',
    'source_url' => 'SourceURL',
    'topic_query_sql' => 'TopicQuerySQL',
    'version' => 'Discourse',
  }

  def self.camelize(basename, abspath)
    return basename.camelize if abspath.ends_with?("onceoff.rb")
    return 'Jobs' if abspath.ends_with?("jobs/base.rb")
    CUSTOM_PATHS.fetch(basename, basename.camelize)
  end
end
