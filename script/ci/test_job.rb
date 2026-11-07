# frozen_string_literal: true
require "json"
require "fileutils"
require_relative "test_execution"
require_relative "test_mapping"

module TestJob
  def self.run(plan_path:, catalog_path:, job_name:, directory:)
    FileUtils.mkdir_p(directory)
    plan = JSON.parse(File.read(plan_path))
    catalog = JSON.parse(File.read(catalog_path))
    job = catalog.fetch("jobs").fetch(job_name)
    main = ENV["GITHUB_REF"] == "refs/heads/main" && ENV["GITHUB_EVENT_NAME"] == "push"
    raise "Main requires a full plan" if main && plan.fetch("mode") != "full"
    collect = main && ENV["TEST_MAPPING_COLLECT"] == "1" && job.fetch("runner") == "rspec"
    ENV["COLLECT_TEST_MAPPING"] = collect ? "1" : "0"
    ENV["COLLECT_RSPEC_MAPPING"] = collect ? "1" : "0"
    ENV["TEST_MAPPING_DIRECTORY"] = File.expand_path("#{directory}/raw")
    reports = []
    if plan.fetch("mode") == "audit"
      reference_path = "#{plan_path}.reference.json"
      reference = JSON.parse(File.read(reference_path))
      unless reference.fetch("mode") == "full" &&
               reference.fetch("revision") == plan.fetch("revision") &&
               reference.fetch("jobs").fetch(job_name) == job.fetch("inventory")
        raise "Invalid audit reference plan"
      end
      run_execution(
        plan_path: reference_path,
        catalog_path: catalog_path,
        job_name: job_name,
        report_path: "#{directory}/reference.json",
      )
      reports << JSON.parse(File.read("#{directory}/reference.json"))
      candidate_path = "#{directory}/candidate-plan.json"
      File.write(candidate_path, JSON.generate(plan.merge("mode" => "select")))
      candidate_reused_reference =
        plan.fetch("jobs").fetch(job_name) == reference.fetch("jobs").fetch(job_name)
      if candidate_reused_reference
        TestExecution.validate_assignment(
          plan: plan.merge("mode" => "select"),
          catalog: catalog,
          job_name: job_name,
        )
        File.write(
          "#{directory}/candidate.json",
          JSON.pretty_generate(reports.first.merge("reused_reference" => true)),
        )
      else
        run_execution(
          plan_path: candidate_path,
          catalog_path: catalog_path,
          job_name: job_name,
          report_path: "#{directory}/candidate.json",
        )
      end
      reports << JSON.parse(File.read("#{directory}/candidate.json"))
      audit = {
        "revision" => plan.fetch("revision"),
        "job" => job_name,
        "candidate_reused_reference" => candidate_reused_reference,
        "candidate_files" => plan.fetch("jobs").fetch(job_name),
        "missed_failures" => reports.first.fetch("failures") - reports.last.fetch("failures"),
        "exact" => reports.all? { |report| report.fetch("exact") },
        "reference_success" => reports.first.fetch("success"),
        "candidate_success" => reports.last.fetch("success"),
        "reference_unreported_failure" => reports.first.fetch("unreported_failure"),
        "candidate_unreported_failure" => reports.last.fetch("unreported_failure"),
        "reference_non_example_failure" => reports.first.fetch("non_example_failure"),
        "candidate_non_example_failure" => reports.last.fetch("non_example_failure"),
        "comparison_complete" =>
          reports.all? do |report|
            report.fetch("exact") && !report.fetch("non_example_failure") &&
              !report.fetch("unreported_failure")
          end,
      }
      File.write("#{directory}/audit.json", JSON.pretty_generate(audit))
    else
      run_execution(
        plan_path: plan_path,
        catalog_path: catalog_path,
        job_name: job_name,
        report_path: "#{directory}/execution.json",
      )
      reports << JSON.parse(File.read("#{directory}/execution.json"))
    end
    unless reports.all? { |report| report.fetch("success") }
      raise "Test execution failed: #{job_name}"
    end
    if collect
      FileUtils.mkdir_p("tmp/test-mappings")
      TestMapping.merge(
        catalog: catalog,
        job_name: job_name,
        directory: ENV.fetch("TEST_MAPPING_DIRECTORY"),
        execution_directory: "#{directory}/execution.json.workers",
        output: "tmp/test-mappings/#{job_name}.json",
      )
    end
  end

  def self.run_execution(plan_path:, catalog_path:, job_name:, report_path:)
    TestExecution.run(
      plan_path: plan_path,
      catalog_path: catalog_path,
      job_name: job_name,
      report_path: report_path,
    )
  rescue RuntimeError
    raise unless File.file?(report_path)
  end
  private_class_method :run_execution
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, "Expected PLAN CATALOG JOB DIRECTORY" unless ARGV.length == 4
    TestJob.run(plan_path: ARGV[0], catalog_path: ARGV[1], job_name: ARGV[2], directory: ARGV[3])
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
