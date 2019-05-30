# frozen_string_literal: true

# simple script to measure memory at boot

if ENV['RAILS_ENV'] != "production"
  exec "RAILS_ENV=production ruby #{__FILE__}"
end

require 'memory_profiler'

MemoryProfiler.report do
  require File.expand_path("../../config/environment", __FILE__)

  Rails.application.routes.recognize_path('abc') rescue nil

  # load up the yaml for the localization bits, in master process
  I18n.t(:posts)

  # load up all models and schema
  (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
    table.classify.constantize.first rescue nil
  end
end.pretty_print
