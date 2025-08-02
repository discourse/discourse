# frozen_string_literal: true

# simple script to measure memory at boot

exec "RAILS_ENV=production ruby #{__FILE__}" if ENV["RAILS_ENV"] != "production"

require "memory_profiler"

MemoryProfiler
  .report do
    require File.expand_path("../../config/environment", __FILE__)

    begin
      Rails.application.routes.recognize_path("abc")
    rescue StandardError
      nil
    end

    # load up the yaml for the localization bits, in master process
    I18n.t(:posts)

    # load up all models and schema
    (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
      begin
        table.classify.constantize.first
      rescue StandardError
        nil
      end
    end
  end
  .pretty_print
