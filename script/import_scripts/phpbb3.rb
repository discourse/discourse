# frozen_string_literal: true

# Importer for phpBB 3.0 and 3.1
# Documentation: https://meta.discourse.org/t/importing-from-phpbb3/30810

if ARGV.length != 1 || !File.exist?(ARGV[0])
  STDERR.puts '', 'Usage of phpBB3 importer:', 'bundle exec ruby phpbb3.rb <path/to/settings.yml>'
  STDERR.puts '', "Use the settings file from #{File.expand_path('phpbb3/settings.yml', File.dirname(__FILE__))} as an example."
  STDERR.puts '', 'Still having problems? Take a look at https://meta.discourse.org/t/importing-from-phpbb3/30810'
  exit 1
end

module ImportScripts
  module PhpBB3
    require_relative 'phpbb3/support/settings'
    require_relative 'phpbb3/database/database'

    @settings = Settings.load(ARGV[0])

    # We need to load the gem files for ruby-bbcode-to-md and the database adapter
    # (e.g. mysql2) before bundler gets initialized by the base importer.
    # Otherwise we get an error since those gems are not always in the Gemfile.
    require 'ruby-bbcode-to-md' if @settings.use_bbcode_to_md

    begin
      @database = Database.create(@settings.database)
    rescue UnsupportedVersionError => error
      STDERR.puts '', error.message
      exit 1
    end

    require_relative 'phpbb3/importer'
    Importer.new(@settings, @database).perform
  end
end
