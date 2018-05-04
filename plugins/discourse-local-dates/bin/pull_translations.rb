#!/usr/bin/env ruby

require 'translations_manager'

YML_DIRS = ['config/locales'].map { |d| File.expand_path(d) }
YML_FILE_PREFIXES = ['client', 'server']

TranslationsManager::TransifexUpdater.new(YML_DIRS, YML_FILE_PREFIXES, *ARGV).perform
