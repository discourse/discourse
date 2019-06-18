# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

queues = %w{default low ultra_low critical}.map { |name| Sidekiq::Queue.new(name) }.lazy.flat_map(&:lazy)

stats = Hash.new(0)

queues.each do |j|
  stats[j.klass] += 1
end

stats.sort_by { |a, b| -b }.each do |name, count|
  puts "#{name}: #{count}"
end

dupes = Hash.new([])
queues.each do |j|
  key = "#{j.klass} #{j.args}"
  dupes[key] << j
end

total = 0

dupes.each do |k, jobs|
  next if jobs.length == 1
  total += job.length - 1
  puts "dupe found"
  p jobs
end

puts
puts "#{total} duplicate jobs found!"
