#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "benchmark-ips"
end

require "benchmark/ips"
require "time"

THE_TIME = Time.now.utc
DATE_TIME = DateTime.now.new_offset(0)

Benchmark.ips do |x|
  x.config(time: 10, warmup: 2)

  x.report("Time#iso8601") { THE_TIME.iso8601 }
  x.report("Time#strftime") { THE_TIME.strftime("%FT%TZ") }
  x.report("DateTime#iso8601") { DATE_TIME.iso8601 }

  x.compare!
end
