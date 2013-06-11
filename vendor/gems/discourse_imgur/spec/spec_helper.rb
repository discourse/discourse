require 'rubygems'
require 'rails'

ENV["RAILS_ENV"] ||= 'test'

RSpec.configure do |config|

  config.mock_framework = :mocha
  config.color_enabled = true

end
