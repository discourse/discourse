module ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector
  @@custom_paths = {}

  def self.setup(basename, klassname, regex = nil)
    @@custom_paths[basename] = Array.wrap(@@custom_paths[basename]) << { value: klassname, regex: regex }
  end

  setup('base', 'Base', /lib\/demon\/base\.rb$/)
  setup('base', 'Jobs')
  setup('canonical_url', 'CanonicalURL')
  setup('homepage_constraint', 'HomePageConstraint')
  setup('ip_addr', 'IPAddr')
  setup('onpdiff', 'ONPDiff')
  setup('onceoff', 'Jobs')
  setup('pop3_polling_enabled_setting_validator', 'POP3PollingEnabledSettingValidator')
  setup('postgresql_fallback_adapter', 'PostgreSQLFallbackHandler')
  setup('regular', 'Jobs')
  setup('scheduled', 'Jobs')
  setup('source_url', 'SourceURL')
  setup('topic_query_sql', 'TopicQuerySQL')
  setup('version', 'Discourse')

  def self.custom_path(basename, abs_path)
    @@custom_paths[basename]&.find { |custom_path| !custom_path[:regex] || abs_path =~ custom_path[:regex] }&.dig(:value)
  end

  def self.camelize(basename, abspath)
    custom_path(basename, abspath) || basename.camelize
  end
end
