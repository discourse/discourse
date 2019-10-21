# frozen_string_literal: true

require 'benchmark/ips'
require File.expand_path("../../config/environment", __FILE__)

conn = ActiveRecord::Base.connection.raw_connection

Benchmark.ips do |b|
  b.report("simple") do
    User.first.name
  end

  b.report("simple with select") do
    User.select("name").first.name
  end

  b.report("pluck with first") do
    User.pluck(:name).first
  end

  b.report("pluck with limit") do
    User.limit(1).pluck(:name).first
  end

  b.report("pluck with pluck_first") do
    User.pluck_first(:name)
  end

  b.report("raw") do
    conn.exec("SELECT name FROM users LIMIT 1").getvalue(0, 0)
  end
end
