# frozen_string_literal: true

# This custom inflector is needed because of our jobs directory structure.
# Ideally, we should not prefix our jobs with a `Jobs` namespace but instead
# have a `Job` suffix to follow the Rails conventions on naming.
#
# Based on:
# https://github.com/rails/rails/blob/75e6c0ac/railties/lib/rails/autoloaders/inflector.rb#L7-L19
module DiscourseInflector
  @overrides = {}

  def self.camelize(basename, abspath)
    return basename.camelize if abspath.ends_with?("onceoff.rb")
    return 'Jobs' if abspath.ends_with?("jobs/base.rb")
    @overrides[basename] || basename.camelize
  end

  def self.inflect(overrides)
    @overrides.merge!(overrides)
  end
end

Rails.autoloaders.each do |autoloader|
  autoloader.inflector = DiscourseInflector

  # We have filenames that do not follow Zeitwerk's camelization convention. Maintain an inflections for these files
  # for now until we decide to fix them one day.
  autoloader.inflector.inflect(
    'canonical_url' => 'CanonicalURL',
    'clean_up_unmatched_ips' => 'CleanUpUnmatchedIPs',
    'homepage_constraint' => 'HomePageConstraint',
    'ip_addr' => 'IPAddr',
    'onpdiff' => 'ONPDiff',
    'pop3_polling_enabled_setting_validator' => 'POP3PollingEnabledSettingValidator',
    'version' => 'Discourse',
    'onceoff' => 'Jobs',
    'regular' => 'Jobs',
    'scheduled' => 'Jobs',
  )
end
