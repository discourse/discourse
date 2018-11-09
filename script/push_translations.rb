#!/usr/bin/env ruby

require 'bundler/inline'

gemfile(true) do
  gem 'translations-manager', git: 'https://github.com/discourse/translations-manager.git'
end

require 'translations_manager'

def expand_path(path)
  File.expand_path("../../#{path}", __FILE__)
end

YML_DIRS = ['config/locales',
            'plugins/poll/config/locales',
            'plugins/discourse-details/config/locales',
            'plugins/discourse-local-dates/config/locales',
            'plugins/discourse-narrative-bot/config/locales',
            'plugins/discourse-nginx-performance-report/config/locales',
            'plugins/discourse-presence/config/locales'].map { |dir| expand_path(dir) }
YML_FILE_PREFIXES = ['server', 'client']
TX_CONFIG = expand_path('.tx/config')

puts ""

resource_names = []
languages = []
parser = OptionParser.new do |opts|
  opts.banner = "Usage: push_translations.rb [options]"

  opts.on("-r", "--resources a,b,c", Array, "Comma separated list of resource names as found in .tx/config") { |v| resource_names = v }
  opts.on("-l", "--languages de,fr", Array, "Comma separated list of languages") { |v| languages = v }
  opts.on("-h", "--help") do
    puts opts
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  STDERR.puts e.message, "", parser
  exit 1
end

if resource_names.empty?
  STDERR.puts "Missing argument: resources", "", parser
  exit 1
end

TranslationsManager::TransifexUploader.new(YML_DIRS, YML_FILE_PREFIXES, resource_names, languages).perform(tx_config_filename: TX_CONFIG)
