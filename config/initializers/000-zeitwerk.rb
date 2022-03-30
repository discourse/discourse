# frozen_string_literal: true

# This custom inflector is needed because of our jobs directory structure.
# Ideally, we should not prefix our jobs with a `Jobs` namespace but instead
# have a `Job` suffix to follow the Rails conventions on naming.
class DiscourseInflector < Zeitwerk::Inflector
  def camelize(basename, abspath)
    return basename.camelize if abspath.ends_with?("onceoff.rb")
    return 'Jobs' if abspath.ends_with?("jobs/base.rb")
    super
  end
end

Rails.autoloaders.each do |autoloader|
  autoloader.inflector = DiscourseInflector.new

  # We have filenames that do not follow Zeitwerk's camelization convention. Maintain an inflections for these files
  # for now until we decide to fix them one day.
  autoloader.inflector.inflect(
    'canonical_url' => 'CanonicalURL',
    'clean_up_unmatched_ips' => 'CleanUpUnmatchedIPs',
    'homepage_constraint' => 'HomePageConstraint',
    'ip_addr' => 'IPAddr',
    'onpdiff' => 'ONPDiff',
    'pop3_polling_enabled_setting_validator' => 'POP3PollingEnabledSettingValidator',
    'html' => 'HTML',
    'json' => 'JSON',
    'csrf_token_verifier' => 'CSRFTokenVerifier',
    'onceoff' => 'Jobs',
    'regular' => 'Jobs',
    'scheduled' => 'Jobs',
  )
end
Rails.autoloaders.main.ignore(
  "lib/tasks",
  "lib/generators",
  "lib/freedom_patches",
)
