# frozen_string_literal: true
require "json"
require "fileutils"
require "digest"
require "pathname"

module TestExecution
  def self.validate_assignment(plan:, catalog:, job_name:)
    job = catalog.fetch("jobs").fetch(job_name)
    if catalog["repository_catalog"]
      require_relative "test_inventory"
      current =
        TestInventory.catalog(revision: catalog.fetch("revision")).fetch("jobs").fetch(job_name)
      unless current.fetch("inventory") == job.fetch("inventory") &&
               current.fetch("environment") == job.fetch("environment")
        raise ArgumentError, "Current checkout does not match the planned environment"
      end
    end
    files = plan.fetch("jobs").fetch(job_name)
    unless %w[full select].include?(plan.fetch("mode")) && plan.fetch("version") == 2 &&
             plan.fetch("revision") == ENV.fetch("GITHUB_SHA") &&
             catalog.fetch("revision") == plan.fetch("revision") &&
             plan.fetch("environments").fetch(job_name) == job.fetch("environment") &&
             files.is_a?(Array) && files.uniq == files &&
             files == job.fetch("inventory").select { |file| plan.fetch("files").include?(file) } &&
             files.all? { |path| File.file?(path) }
      raise ArgumentError, "Invalid or stale job assignment"
    end
    files
  end

  def self.run(plan_path:, catalog_path:, job_name:, report_path:)
    FileUtils.rm_f(report_path)
    plan = JSON.parse(File.read(plan_path))
    catalog = JSON.parse(File.read(catalog_path))
    files = validate_assignment(plan: plan, catalog: catalog, job_name: job_name)
    job = catalog.fetch("jobs").fetch(job_name)
    root = Dir.pwd
    inventory_paths = job.fetch("inventory").to_h { |path| [File.realpath(path), path] }
    directory = "#{File.expand_path(report_path)}.workers"
    raise ArgumentError, "Execution report directory already exists" if File.exist?(directory)
    FileUtils.mkdir_p(directory)
    environment =
      job.fetch("env", {}).merge(
        "TEST_SELECTION_ROOT" => root,
        "TEST_SELECTION_ENVIRONMENT" => job.fetch("environment"),
        "RSPEC_MAPPING_DIRECTORY" => ENV.fetch("TEST_MAPPING_DIRECTORY", "#{directory}/mapping"),
        "TEST_EXECUTION_DIRECTORY" => directory,
        "TEST_SELECTION_ALL" => files == job.fetch("inventory") ? "1" : "0",
      )
    environment["QUNIT_SEED"] = catalog.fetch("seed").to_s if job.fetch("runner") == "qunit" &&
      catalog.key?("seed")
    if job.fetch("runner") == "rspec"
      environment["TEST_SELECTION_INVENTORY"] = "#{directory}/inventory.json"
      File.write(environment.fetch("TEST_SELECTION_INVENTORY"), JSON.generate(inventory_paths.keys))
      environment["TEST_SELECTION_ORIGINAL_RUBYOPT"] = ENV.fetch("RUBYOPT", "")
      environment["BUNDLER_ORIG_RUBYOPT"] = ENV.fetch("BUNDLER_ORIG_RUBYOPT") do
        environment.fetch("TEST_SELECTION_ORIGINAL_RUBYOPT")
      end
      environment["RUBYOPT"] = [
        ENV["RUBYOPT"],
        "-rbundler/setup",
        "-r#{root}/script/ci/rspec_execution.rb",
      ].compact.join(" ")
    end
    working_directory = File.expand_path(job.fetch("cwd", "."))
    arguments =
      files.map do |path|
        Pathname
          .new(File.expand_path(path))
          .relative_path_from(Pathname.new(working_directory))
          .to_s
      end
    command = job.fetch("command") + arguments
    if job.fetch("runner") == "rspec"
      if job.key?("order")
        command += ["--order", [job.fetch("order"), catalog["seed"]].compact.join(":")]
      elsif catalog.key?("seed")
        command += ["--seed", catalog.fetch("seed").to_s]
      end
    end
    if job.fetch("runner") == "vitest"
      exclusions =
        (job.fetch("inventory") - files).flat_map do |path|
          [
            "--exclude",
            Pathname
              .new(File.expand_path(path))
              .relative_path_from(Pathname.new(working_directory))
              .to_s,
          ]
        end
      command += exclusions + ["--reporter=json", "--outputFile=#{directory}/vitest.json"]
    end
    turbo = job.fetch("command").first == "bin/turbo_rspec"
    command += ["--execution-plan", "#{directory}/execution-manifest.json"] if turbo
    success = files.empty? || system(environment, *command, chdir: job.fetch("cwd", "."))
    pattern = job.fetch("runner") == "qunit" ? "qunit" : "rspec"
    records = Dir["#{directory}/#{pattern}-*.json"].map { |path| JSON.parse(File.read(path)) }
    if job.fetch("runner") == "vitest" && files.any?
      raw = JSON.parse(File.read("#{directory}/vitest.json"))
      records = [
        {
          "revision" => plan.fetch("revision"),
          "files" =>
            raw
              .fetch("testResults")
              .map do |result|
                File.realpath(result.fetch("name")).delete_prefix("#{File.realpath(root)}/")
              end,
          "examples" => raw.fetch("numTotalTests"),
          "failures" =>
            raw
              .fetch("testResults")
              .flat_map do |result|
                result
                  .fetch("assertionResults")
                  .select { |example| example.fetch("status") == "failed" }
                  .map { |example| example.fetch("fullName") }
              end,
        },
      ]
    end
    normalize = ->(path) do
      expanded = File.expand_path(path, root)
      absolute = File.exist?(expanded) ? File.realpath(expanded) : expanded
      inventory_paths.fetch(absolute, absolute)
    end
    loaded = records.flat_map { |record| record.fetch("files") }.map(&normalize).uniq.sort
    executed =
      records
        .flat_map do |record|
          job.fetch("runner") == "rspec" ? record.fetch("executed_files") : record.fetch("files")
        end
        .map(&normalize)
        .uniq
        .sort
    exact =
      if %w[rspec qunit vitest].include?(job.fetch("runner"))
        loaded == files.sort && (executed - files).empty? &&
          records.all? { |record| record.fetch("revision") == plan.fetch("revision") }
      else
        files.empty?
      end
    if job.fetch("runner") == "rspec" && catalog.key?("seed")
      exact &&= records.all? { |record| record.fetch("seed") == catalog.fetch("seed") }
    end
    missing_roles = []
    if turbo && files.any?
      manifest = JSON.parse(File.read("#{directory}/execution-manifest.json"))
      missing_roles =
        manifest
          .fetch("workers")
          .filter_map do |identity, assigned|
            unless records.any? { |record|
                     record.fetch("identity") == identity &&
                       record.fetch("pid") == assigned.fetch("pid") &&
                       record.fetch("files").map(&normalize).sort == assigned.fetch("files").sort
                   }
              identity
            end
          end
      exact &&= manifest.fetch("revision") == plan.fetch("revision") && missing_roles.empty?
    end
    if job.fetch("runner") == "qunit"
      exact &&= records.all? { |record| record.fetch("registrations_complete") }
    end
    non_example_failure = records.any? { |record| record.fetch("non_example_failure", false) }
    report = {
      revision: plan.fetch("revision"),
      plan_sha256: Digest::SHA256.file(plan_path).hexdigest,
      job: job_name,
      assigned: files,
      loaded: loaded,
      executed_files: executed,
      missing_files: files - loaded,
      unassigned_files: (loaded | executed) - files,
      missing_roles: missing_roles,
      examples: records.sum { |record| record.fetch("examples", 0) },
      failures: records.flat_map { |record| record.fetch("failures", []) }.uniq.sort,
      command: command,
      process_success: !!success,
      unreported_failure:
        !success &&
          records.none? do |record|
            record.fetch("failures", []).any? || record.fetch("non_example_failure", false)
          end,
      non_example_failure: non_example_failure,
      success: success && exact && !non_example_failure,
      exact: exact,
    }
    File.write(report_path, JSON.pretty_generate(report))
    raise "Execution failed or did not match assignment: #{job_name}" unless report.fetch(:success)
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, "Expected PLAN CATALOG JOB REPORT" unless ARGV.length == 4
    TestExecution.run(
      plan_path: ARGV[0],
      catalog_path: ARGV[1],
      job_name: ARGV[2],
      report_path: ARGV[3],
    )
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
