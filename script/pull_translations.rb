#!/usr/bin/env ruby

require 'bundler/inline'

gemfile(true) do
  gem 'translations-manager', git: 'https://github.com/discourse/translations-manager.git'
end

require 'translations_manager'

def expand_path(path)
  File.expand_path("../../#{path}", __FILE__)
end

def supported_locales
  Dir.glob(expand_path('config/locales/client.*.yml'))
    .map { |x| x.split('.')[-2] }
    .select { |x| x != 'en' }
    .sort
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

if TranslationsManager::SUPPORTED_LOCALES != supported_locales
  STDERR.puts <<~MESSAGE

    The supported locales are out of sync.
    Please update the TranslationsManager::SUPPORTED_LOCALES in translations-manager.
    https://github.com/discourse/translations-manager

    The following locales are currently supported by Discourse:

  MESSAGE

  STDERR.puts locales.map { |l| "'#{l}'" }.join(",\n")
  exit 1
end

TranslationsManager::TransifexUpdater.new(YML_DIRS, YML_FILE_PREFIXES, *ARGV).perform(tx_config_filename: TX_CONFIG)
