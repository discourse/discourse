if ARGV.length != 1 || !File.exists?(ARGV[0])
  STDERR.puts '', 'Usage of mbox importer:', 'bundle exec ruby mbox-experimental.rb <path/to/settings.yml>'
  STDERR.puts '', "Use the settings file from #{File.expand_path('mbox/settings.yml', File.dirname(__FILE__))} as an example."
  exit 1
end

module ImportScripts
  module Mbox
    require_relative 'mbox/support/settings'

    @settings = Settings.load(ARGV[0])

    require_relative 'mbox/importer'
    Importer.new(@settings).perform
  end
end
