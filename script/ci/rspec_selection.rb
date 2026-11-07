# frozen_string_literal: true

require_relative "../../lib/rspec_test_selection"

command = ARGV.shift
directory = "tmp/rspec-mapping"
FileUtils.mkdir_p(directory)

case command
when "plan"
  baseline_path = File.join(directory, "baseline.json")
  baseline =
    begin
      JSON.parse(File.read(baseline_path)) if File.file?(baseline_path)
    rescue JSON::ParserError
      nil
    end
  baseline = nil unless baseline.is_a?(Hash)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  if baseline
    revision = baseline["revision"]
    if !revision.is_a?(String) || !revision.match?(/\A[0-9a-f]{40}\z/)
      baseline = nil
    elsif !system("git", "cat-file", "-e", "#{revision}^{commit}", out: File::NULL, err: File::NULL)
      baseline = nil unless system("git", "fetch", "--no-tags", "--depth=1", "origin", revision)
    end
  end
  plan = RspecTestSelection.plan(root: Dir.pwd, baseline: baseline)
  plan["selection_seconds"] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  if ENV["GITHUB_EVENT_NAME"] == "pull_request" && plan["mode"] == "subset"
    begin
      proposal = JSON.parse(File.read(File.join(directory, "llm.json")))
      valid =
        proposal["head_sha"] == ENV["RSPEC_PR_HEAD_SHA"] &&
          proposal["base_sha"] == ENV["RSPEC_PR_BASE_SHA"] && proposal["mode"] == "subset" &&
          proposal["specs"].is_a?(Array) &&
          (proposal["specs"] - RspecTestSelection.inventory(Dir.pwd)).empty?
      raise "Invalid LLM proposal" unless valid
      plan["deterministic_specs"] = plan["specs"]
      plan["specs"] = (plan["specs"] + proposal["specs"]).uniq.sort
      plan["llm"] = proposal
    rescue StandardError
      plan["mode"] = "full"
      plan["reason"] = "LLM proposal unavailable or uncertain"
      plan["specs"] = RspecTestSelection.inventory(Dir.pwd)
    end
  end
  File.write(File.join(directory, "selection.json"), JSON.pretty_generate(plan))
  puts JSON.generate(
         plan.reject { |key| key == "specs" }.merge("selected_specs" => plan["specs"].size),
       )
when "report"
  plan = JSON.parse(File.read(File.join(directory, "selection.json")))
  records = Dir.glob(File.join(directory, "raw/*.json")).map { |path| JSON.parse(File.read(path)) }
  outcomes = records.flat_map { |record| record.fetch("outcomes") }
  failures = outcomes.select { |example| example["status"] == "failed" }
  missed = failures.reject { |example| plan.fetch("specs").include?(example["spec"]) }
  durations =
    outcomes
      .group_by { |example| example["spec"] }
      .transform_values do |group|
        group.sum { |example| example.fetch("duration_seconds", 0).to_f }
      end
  report = {
    "selection" => plan,
    "examples" => outcomes.size,
    "failures" => failures.size,
    "missed_failures" => missed,
    "spec_seconds" => durations,
    "worker_cpu_seconds" => records.sum { |record| record.fetch("cpu_seconds", 0) },
  }
  report["excluded_example_seconds"] = durations
    .reject { |spec, _| plan.fetch("specs").include?(spec) }
    .values
    .sum
  if plan["deterministic_specs"]
    report["deterministic_missed_failures"] = failures.reject do |example|
      plan["deterministic_specs"].include?(example["spec"])
    end
    report["llm_added_specs"] = plan["specs"] - plan["deterministic_specs"]
  end
  File.write(File.join(directory, "report.json"), JSON.pretty_generate(report))
  if ENV["COLLECT_RSPEC_MAPPING"] == "1"
    mapping = RspecTestSelection.merge(root: Dir.pwd, records: records)
    File.write(File.join(directory, "mapping.json"), JSON.generate(mapping))
  end
  if ENV["GITHUB_STEP_SUMMARY"]
    File.open(ENV["GITHUB_STEP_SUMMARY"], "a") do |summary|
      summary.puts "RSpec selection observation: #{plan["specs"].size}/#{plan["total_specs"]} spec files, #{failures.size} failing examples, #{missed.size} missed. Reason: #{plan["reason"]}. All tests still ran."
    end
  end
else
  abort "Expected plan or report"
end
