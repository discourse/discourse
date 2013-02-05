require 'discourse_task/version'
require 'discourse_task/engine' if defined?(Rails) && (!Rails.env.test?)

I18n.load_path << "#{File.dirname(__FILE__)}/discourse_task/locale/en.yml"