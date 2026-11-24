# frozen_string_literal: true

require "json"
require_relative "../core_system_test_selection"

class CoreSystemResults
  def initialize(directory)
    @workers = {}
    @incomplete_journals = false
    @results =
      Dir[File.join(directory, "examples-*.jsonl")]
        .each_with_object({}) do |file, results|
          examples = read_journal(file)
          if !examples
            @incomplete_journals = true
            next
          end
          worker = File.basename(file, ".jsonl").delete_prefix("examples-")
          @workers[worker] = examples.any?
          examples.each do |example|
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
    raise "Incomplete Core system test journal" if @incomplete_journals
    all_files = CoreSystemTestSelection.inventory
    actual_files = @results.map { |example| example.fetch("file") }.uniq
    raise "Incomplete Core system test results" unless (all_files - actual_files).empty?
    if @results.any? { |example| example.fetch("status") == "failed" }
      raise "Core system examples failed"
    end

    passed = @results.select { |example| example.fetch("status") == "passed" }
    attempts = passed.to_h { |example| [example.fetch("id"), example.fetch("pid")] }
    File.write(File.join(directory, "active-attempts.json"), JSON.generate(attempts))
    passed_by_worker = passed.group_by { |example| example.fetch("pid") }
    File.write(File.join(directory, "recorded-workers.json"), JSON.generate(@workers))
    File.write(
      File.join(directory, "passed-specs-by-worker.json"),
      JSON.generate(
        passed_by_worker.transform_values { |rows| rows.map { |row| row.fetch("file") }.uniq },
      ),
    )
  end

  def report(plan:, output:, outcome:, flaky_tests_file:)
    failed_examples = @results.select { |example| example.fetch("status") == "failed" }
    failures = failed_examples.map { |example| example.fetch("file") }.uniq.sort
    selected = plan.fetch("selected_files").to_set
    fallback = plan.fetch("full_suite_fallback")
    observed_files = @results.map { |example| example.fetch("file") }.to_set
    outcome_matches =
      outcome == (failures.empty? ? "success" : "failure") &&
        failures_agree_with_retries?(failed_examples:, flaky_tests_file:)
    complete =
      !@incomplete_journals && outcome_matches && !observed_files.empty? &&
        observed_files == CoreSystemTestSelection.inventory.to_set
    measured_seconds = @results.sum { |example| example.fetch("seconds") }
    selected_seconds =
      @results.sum do |example|
        selected.include?(example.fetch("file")) ? example.fetch("seconds") : 0
      end
    report =
      plan.merge(
        full_ci_outcome: outcome,
        observed_files: observed_files.size,
        measurement_complete: complete,
        failed_files: failures,
        omitted_failed_files: complete ? failures.reject { |file| selected.include?(file) } : nil,
        contains_failed_file:
          (
            if complete && !fallback && failures.any?
              failures.any? { |file| selected.include?(file) }
            else
              nil
            end
          ),
        observed_example_seconds: measured_seconds.round(3),
        selected_example_seconds: selected_seconds.round(3),
      )
    File.write(output, JSON.pretty_generate(report))
    summary(report)
  end

  private

  def failures_agree_with_retries?(failed_examples:, flaky_tests_file:)
    return true unless flaky_tests_file && File.file?(flaky_tests_file)

    flaky_tests = JSON.parse(File.read(flaky_tests_file))
    recovered_locations =
      flaky_tests.map { |example| example.fetch("location_rerun_argument") }.to_set
    failed_examples.none? { |example| recovered_locations.include?(example.fetch("location")) }
  rescue StandardError => error
    warn "Cannot verify Core system retries: #{error.message}"
    false
  end

  def read_journal(file)
    raise "Expected a regular file" unless File.file?(file)
    examples = File.readlines(file).map { |line| JSON.parse(line) }
    expected = examples.shift&.fetch("expected_example_ids", nil)
    completed = examples.pop == { "completed" => true }
    if expected && completed && examples.map { |example| example.fetch("id") }.sort == expected.sort
      return examples
    end
    warn "Incomplete Core system test journal: #{file}"
    nil
  rescue StandardError => error
    warn "Cannot read Core system test journal: #{file}: #{error.message}"
    nil
  end

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
      file.puts "| Time to decide | #{report.fetch("selector_seconds")} s |"
      file.puts "| Full suite outcome | #{report.fetch(:full_ci_outcome)} |"
      file.puts "| Complete test results | #{report.fetch(:measurement_complete) ? "Yes" : "No"} |"
      omitted = report.fetch(:omitted_failed_files)
      file.puts "| Failing files omitted | #{omitted ? "#{omitted.size} of #{report.fetch(:failed_files).size}" : "No measurement"} |"
      contains_failed_file =
        case report.fetch(:contains_failed_file)
        when true
          "Yes"
        when false
          "No"
        else
          if !report.fetch(:measurement_complete)
            "No measurement"
          elsif report.fetch("full_suite_fallback")
            "Full suite fallback"
          else
            "No failures"
          end
        end
      file.puts "| Would select a file that failed? | #{contains_failed_file} |"
    end
  end
end

command, directory, *arguments = ARGV
results = CoreSystemResults.new(directory)
case command
when "prepare"
  results.prepare_mapping(directory: arguments.fetch(0))
when "report"
  plan, output, flaky_tests_file = arguments
  results.report(
    plan: JSON.parse(File.read(plan)),
    output:,
    outcome: ENV.fetch("CORE_SYSTEM_TEST_OUTCOME"),
    flaky_tests_file:,
  )
else
  abort "Expected prepare or report"
end
