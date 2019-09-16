# frozen_string_literal: true

module ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector
  CUSTOM_PATHS = {
    'base' => 'Jobs',
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

  def self.camelize(basename, _abspath)
    return basename.camelize if _abspath =~ /onceoff\.rb$/
    CUSTOM_PATHS.fetch(basename, basename.camelize)
  end
end
