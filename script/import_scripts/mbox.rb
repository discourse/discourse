# frozen_string_literal: true

if ARGV.length != 1 || !File.exist?(ARGV[0])
  STDERR.puts '', 'Usage of mbox importer:', 'bundle exec ruby mbox.rb <path/to/settings.yml>'
  STDERR.puts '', "Use the settings file from #{File.expand_path('mbox/settings.yml', File.dirname(__FILE__))} as an example."
  exit 1
end

module ImportScripts
  module Mbox
    require_relative 'mbox/importer'
    Importer.new(ARGV[0]).perform
  end
end
