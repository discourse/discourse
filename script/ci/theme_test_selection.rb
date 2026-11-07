# frozen_string_literal: true
require_relative "../../config/environment"

files = ARGV
raise "Theme selection requires explicit test files" if files.empty?
groups =
  files.group_by do |path|
    path[%r{\A((?:tmp/)?themes/[^/]+)/test/}, 1] || raise("Invalid theme test path: #{path}")
  end
groups.each do |directory, paths|
  core = directory.start_with?("themes/")
  theme_id =
    if core
      SystemThemesManager.sync_theme!(File.basename(directory))
      Theme::CORE_THEMES.fetch(File.basename(directory))
    else
      RemoteTheme.import_theme_from_directory(File.expand_path(directory)).id
    end
  environment = {
    "DISCOURSE_DEV_DB" => "discourse_test",
    "THEME_IDS" => nil,
    "THEME_ID" => theme_id.to_s,
    "EMBER_RAISE_ON_DEPRECATION" => core ? "1" : nil,
    "QUNIT_RAILS_ENV" => "test",
    "LOAD_PLUGINS" => "1",
  }
  success =
    system(
      environment,
      "bin/qunit",
      "--standalone",
      "--exact-files",
      "--qunit-path",
      "/theme-qunit",
      "--theme-id",
      theme_id.to_s,
      *paths,
    )
  exit($?.exitstatus || 1) unless success
end
