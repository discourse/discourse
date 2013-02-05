require 'discourse_poll/version'
require 'discourse_poll/engine' if defined?(Rails) && (!Rails.env.test?)


I18n.load_path << "#{File.dirname(__FILE__)}/discourse_poll/locale/en.yml"