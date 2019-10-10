# frozen_string_literal: true

# simple script to measure largest objects in memory post boot

if ENV['RAILS_ENV'] != "production"
  exec "RAILS_ENV=production ruby #{__FILE__}"
end

require 'objspace'

ObjectSpace.trace_object_allocations do

  require File.expand_path("../../config/environment", __FILE__)

  Rails.application.routes.recognize_path('abc') rescue nil

  # load up the yaml for the localization bits, in master process
  I18n.t(:posts)

  RailsMultisite::ConnectionManagement.each_connection do
    (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
      table.classify.constantize.first rescue nil
    end
  end

end

5.times do
  GC.start(full_mark: true, immediate_sweep: true)
end

[String, Array, Hash].each do |klass|
  ObjectSpace.each_object(klass).sort { |a, b| b.length <=> a.length }.first(50).each do |obj|
    puts "#{klass} size: #{obj.length} #{ObjectSpace.allocation_sourcefile(obj)} #{ObjectSpace.allocation_sourceline(obj)}"
  end
end
