# frozen_string_literal: true

Rails.autoloaders.each do |autoloader|
  autoloader.inflector = DiscourseInflector

  # We have filenames that do not follow Zeitwerk's camelization convention. Maintain an inflections for these files
  # for now until we decide to fix them one day.
  autoloader.inflector.inflect(
    "canonical_url" => "CanonicalURL",
    "clean_up_unmatched_ips" => "CleanUpUnmatchedIPs",
    "homepage_constraint" => "HomePageConstraint",
    "ip_addr" => "IPAddr",
    "onpdiff" => "ONPDiff",
    "pop3_polling_enabled_setting_validator" => "POP3PollingEnabledSettingValidator",
    "version" => "Discourse",
    "onceoff" => "Jobs",
    "regular" => "Jobs",
    "scheduled" => "Jobs",
    "google_oauth2_authenticator" => "GoogleOAuth2Authenticator",
    "omniauth_strategies" => "OmniAuthStrategies",
    "csrf_token_verifier" => "CSRFTokenVerifier",
    "html" => "HTML",
    "json" => "JSON",
    "ssrf_detector" => "SSRFDetector",
    "http" => "HTTP",
    "gc_stat_instrumenter" => "GCStatInstrumenter",
  )
end
Rails.autoloaders.main.ignore(
  "lib/tasks",
  "lib/generators",
  "lib/freedom_patches",
  "lib/i18n/backend",
  "lib/unicorn_logstash_patch.rb",
)
