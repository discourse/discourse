# frozen_string_literal: true

require "json"
require_relative "../core_system_test_selection"

class CoreSystemResults
  def initialize(directory)
    @results =
      Dir[File.join(directory, "examples-*.jsonl")]
        .each_with_object({}) do |file, results|
          File.foreach(file) do |line|
            example = JSON.parse(line)
            id = example.fetch("id")
            previous = results[id]
            if !previous || previous.fetch("finished_ns") < example.fetch("finished_ns")
              results[id] = example
            end
          end
        end
        .values
  end

  def prepare_mapping(directory:)
    all_files = CoreSystemTestSelection.inventory
    actual_files = @results.map { |example| example.fetch("file") }.uniq
    raise "Incomplete Core system test results" unless (all_files - actual_files).empty?
    if @results.any? { |example| example.fetch("status") == "failed" }
      raise "Core system examples failed"
    end

    passed = @results.select { |example| example.fetch("status") == "passed" }
    attempts = passed.to_h { |example| [example.fetch("id"), example.fetch("pid")] }
    File.write(File.join(directory, "passed-examples.json"), JSON.generate(attempts.keys))
    File.write(File.join(directory, "active-attempts.json"), JSON.generate(attempts))
  end

  def report(plan:, output:, outcome:)
    failures =
      @results
        .filter_map { |example| example.fetch("file") if example.fetch("status") == "failed" }
        .uniq
        .sort
    selected = plan.fetch("selected_files").to_set
    fallback = plan.fetch("full_suite_fallback")
    observed_files = @results.map { |example| example.fetch("file") }.to_set
    measured_seconds = @results.sum { |example| example.fetch("seconds") }
    selected_seconds =
      @results.sum do |example|
        selected.include?(example.fetch("file")) ? example.fetch("seconds") : 0
      end
    report =
      plan.merge(
        full_ci_outcome: outcome,
        observed_files: observed_files.size,
        failed_files: failures,
        omitted_failed_files: failures.reject { |file| selected.include?(file) },
        would_block:
          fallback || failures.empty? ? nil : failures.any? { |file| selected.include?(file) },
        observed_example_seconds: measured_seconds.round(3),
        selected_example_seconds: selected_seconds.round(3),
      )
    File.write(output, JSON.pretty_generate(report))
    summary(report)
  end

  private

  def summary(report)
    File.open(ENV.fetch("GITHUB_STEP_SUMMARY"), "a") do |file|
      file.puts "### Core system test selection in shadow"
      file.puts
      file.puts "| Metric | Result |"
      file.puts "| --- | --- |"
      file.puts "| Would run | #{report.fetch("selected_files").size} of #{report.fetch("total_files")} files |"
      total = report.fetch("total_files")
      reduction = total.zero? ? 0 : (100.0 * report.fetch("fewer_files") / total).round(1)
      file.puts "| Fewer files | #{report.fetch("fewer_files")} (#{reduction}%) |"
      file.puts "| Map commit | #{report.fetch("map_revision") || "Unavailable"} |"
      file.puts "| Paths changed since collection | #{report.fetch("main_drift").size} |"
      file.puts "| Full suite fallback | #{report.fetch("full_suite_fallback")&.tr("_", " ") || "None"} |"
      file.puts "| Selector time | #{report.fetch("selector_seconds")} s |"
      file.puts "| Full suite outcome | #{report.fetch(:full_ci_outcome)} |"
      file.puts "| Failing files omitted | #{report.fetch(:omitted_failed_files).size} of #{report.fetch(:failed_files).size} |"
      would_block =
        case report.fetch(:would_block)
        when true
          "Yes"
        when false
          "No"
        else
          "No measurement"
        end
      file.puts "| Would the subset block the PR? | #{would_block} |"
    end
  end
end

command, directory, *arguments = ARGV
results = CoreSystemResults.new(directory)
case command
when "prepare"
  results.prepare_mapping(directory: arguments.fetch(0))
when "report"
  plan, output = arguments
  results.report(
    plan: JSON.parse(File.read(plan)),
    output:,
    outcome: ENV.fetch("CORE_SYSTEM_TEST_OUTCOME"),
  )
else
  abort "Expected prepare or report"
end
