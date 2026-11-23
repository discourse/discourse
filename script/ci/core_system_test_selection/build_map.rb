# frozen_string_literal: true

require "json"
require_relative "../core_system_test_selection"

directory, browser_file, output = ARGV
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
unless Dir[File.join(directory, "browser-errors-*.log")].empty?
  raise "Browser collection encountered errors"
end

browser = JSON.parse(File.read(browser_file))
raise "Browser assets are incomplete" unless browser.fetch("missing_asset_maps").empty?

files = CoreSystemTestSelection.inventory
observed = browser.fetch("observed_example_ids").to_set
expected = JSON.parse(File.read(File.join(directory, "passed-examples.json"))).to_set
raise "Browser coverage missed passed examples" if expected.empty? || !expected.subset?(observed)

dependencies = browser.fetch("tests_by_source").transform_values(&:to_set)
boot = Set.new
ruby_reports = Dir[File.join(directory, "ruby-*.json")]
raise "No Ruby coverage" if ruby_reports.empty?
ruby_reports.each do |path|
  result = JSON.parse(File.read(path))
  boot.merge(result.fetch("boot_sources"))
  result
    .fetch("dependencies")
    .each do |spec, sources|
      raise "Unexpected spec #{spec}" unless files.member?(spec)
      sources.each { |source| (dependencies[source] ||= Set.new).add(spec) }
    end
end
raise "Ruby coverage missed application boot" unless boot.member?("config/application.rb")

payload = {
  version: CoreSystemTestSelection::MAP_VERSION,
  revision: CoreSystemTestSelection.git("rev-parse", "HEAD").strip,
  spec_files: files,
  boot_sources: boot.to_a.sort,
  tests_by_source: dependencies.transform_values { |specs| specs.to_a.sort },
  build_seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3),
}
File.write(output, JSON.generate(payload))
