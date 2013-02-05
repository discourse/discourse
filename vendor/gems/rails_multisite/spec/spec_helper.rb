require 'rubygems'
require 'rails'
require 'active_record'


ENV["RAILS_ENV"] ||= 'test'
RSpec.configure do |config|

  config.color_enabled = true
  
  config.before(:suite) do
    ActiveRecord::Base.configurations['test'] = (YAML::load(File.open("spec/fixtures/database.yml"))['test'])
  end

end


