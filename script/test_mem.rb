# frozen_string_literal: true

start = Time.now
require "objspace"
require File.expand_path("../../config/environment", __FILE__)

# preload stuff
I18n.t(:posts)

# load up all models and schema
(ActiveRecord::Base.connection.tables - %w[schema_migrations]).each do |table|
  begin
    table.classify.constantize.first
  rescue StandardError
    nil
  end
end

# router warm up
begin
  Rails.application.routes.recognize_path("abc")
rescue StandardError
  nil
end

puts "Ruby version #{RUBY_VERSION} p#{RUBY_PATCHLEVEL}"

puts "Bootup time: #{Time.now - start} secs"

GC.start

puts "RSS: #{`ps -o rss -p #{$$}`.chomp.split("\n").last.to_i} KB"

s =
  ObjectSpace
    .each_object(String)
    .map do |o|
      ObjectSpace.memsize_of(o) + 40 # rvalue size on x64
    end

puts "Total strings: #{s.count} space used: #{s.sum} bytes"
