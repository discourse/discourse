# frozen_string_literal: true

require "benchmark/ips"
require File.expand_path("../../config/environment", __FILE__)

conn = ActiveRecord::Base.connection.raw_connection

Benchmark.ips do |b|
  b.report("simple") { User.first.name }

  b.report("simple with select") { User.select("name").first.name }

  b.report("pluck with first") { User.pluck(:name).first }

  b.report("pluck with limit") { User.limit(1).pluck(:name).first }

  b.report("pluck with pick") { User.pick(:name) }

  b.report("raw") { conn.exec("SELECT name FROM users LIMIT 1").getvalue(0, 0) }
end
