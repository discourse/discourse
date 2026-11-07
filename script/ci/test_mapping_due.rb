# frozen_string_literal: true
require "time"
require_relative "test_mapping_download"

module TestMappingDue
  def self.due?(interval:, now: Time.now)
    raise ArgumentError, "Invalid collection interval" if interval < 0
    producers =
      %w[tests migration-tests].map { |workflow| TestMappingDownload.latest(workflow: workflow) }
    return true if producers.any?(&:nil?)
    unless producers.map { |producer| producer.fetch("run").fetch("id") }.uniq.length == 1
      return true
    end
    producers.any? do |producer|
      now - Time.iso8601(producer.fetch("artifact").fetch("created_at")) >= interval
    end
  end
end

if $PROGRAM_NAME == __FILE__
  interval = Integer(ENV.fetch("TEST_MAPPING_INTERVAL_SECONDS", "86400"), 10)
  raise ArgumentError, "Invalid collection interval" if interval < 0
  begin
    due = TestMappingDue.due?(interval: interval)
  rescue StandardError => error
    warn "Cannot establish mapping freshness: #{error.message}"
    due = true
  end
  File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |file| file.puts "due=#{due}" }
end
