# frozen_string_literal: true
require "json"
require "fileutils"
require_relative "test_inventory"
require_relative "test_plan"

unless ARGV.length == 2 && %w[tests migration-tests].include?(ARGV[0])
  raise ArgumentError, "Expected tests|migration-tests DIRECTORY"
end
workflow, directory = ARGV
FileUtils.mkdir_p(directory)
revision = ENV.fetch("GITHUB_SHA")
catalog = TestInventory.catalog(revision: revision)
catalog["global_inventory"] = catalog
  .fetch("jobs")
  .values
  .flat_map { |job| job.fetch("inventory") }
  .uniq
catalog
  .fetch("jobs")
  .select! { |name, _| name.start_with?("migrations-") == (workflow == "migration-tests") }
if ENV["TEST_MAPPING_BACKEND_ONLY"] == "1"
  catalog.fetch("jobs").select! { |name, _| %w[core-backend plugins-backend].include?(name) }
end
File.write("#{directory}/catalog.json", JSON.pretty_generate(catalog))
event = JSON.parse(File.read(ENV.fetch("GITHUB_EVENT_PATH")))
main = ENV["GITHUB_EVENT_NAME"] == "push" && ENV["GITHUB_REF"] == "refs/heads/main"
pull_request = ENV["GITHUB_EVENT_NAME"] == "pull_request"
mode = pull_request ? ENV.fetch("TEST_SELECTION_MODE", "audit") : "full"
raise ArgumentError, "Invalid selection mode" unless %w[full audit select].include?(mode)
audit_percent = Integer(ENV.fetch("TEST_SELECTION_AUDIT_PERCENT", "10"), 10)
raise ArgumentError, "Invalid audit percentage" unless (0..100).cover?(audit_percent)
mode = "audit" if mode == "select" && revision[0, 8].to_i(16) % 100 < audit_percent
base = pull_request ? event.fetch("pull_request").fetch("base").fetch("sha") : revision
TestPlan.prepare(
  catalog_path: "#{directory}/catalog.json",
  mapping_directory: "#{directory}/mappings",
  base: base,
  revision: revision,
  output: "#{directory}/plan.json",
  mode: mode,
  main: main,
)

if ENV["GITHUB_OUTPUT"]
  plan = JSON.parse(File.read("#{directory}/plan.json"))
  groups = {
    %w[core backend] => ["core-backend"],
    %w[core frontend] => %w[core-frontend asset-processor],
    %w[core system] => ["core-system"],
    %w[plugins backend] => ["plugins-backend"],
    %w[plugins frontend] => ["plugins-frontend"],
    %w[core-plugins system] => ["core-plugins-system"],
    %w[chat system] => ["chat-system"],
    %w[official-plugins system] => ["official-plugins-system"],
    %w[themes frontend] => ["themes-frontend"],
    %w[themes system] => ["themes-system"],
  }
  entries =
    groups.filter_map do |(target, build_type), owners|
      next unless owners.any? { |owner| catalog.fetch("jobs").key?(owner) }
      next if mode == "select" && owners.none? { |owner| plan.fetch("jobs").fetch(owner).any? }
      { "target" => target, "build_type" => build_type }
    end
  File.open(ENV.fetch("GITHUB_OUTPUT"), "a") do |file|
    file.puts "matrix=#{JSON.generate("include" => entries)}"
    file.puts "has_tests=#{!entries.empty?}"
    file.puts "mode=#{mode}"
  end
end
