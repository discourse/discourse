# frozen_string_literal: true

if Rails.env.local?
  require "rspec/core/rake_task"

  RSpec::Core::RakeTask.new(:spec)
end
