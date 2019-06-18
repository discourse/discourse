# frozen_string_literal: true

if Rails.env.development? || Rails.env.test?
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)
end
