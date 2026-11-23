# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "Core system test results" do
  let(:scripts) { File.expand_path("../../script/ci/core_system_test_selection", __dir__) }
  let(:spec_file) { "spec/system/sidebar_spec.rb" }
  let(:example_id) { "./#{spec_file}[1:1]" }

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it "preserves the RSpec outcome when the shadow journal cannot be opened" do
    spec_path = File.join(@directory, "passing_spec.rb")
    File.write(spec_path, 'RSpec.describe("fixture") { it("passes") { expect(true).to eq(true) } }')
    results_path = File.join(@directory, "results")
    File.write(results_path, "this path is a file")

    stdout, stderr, status =
      Open3.capture3(
        {
          "CORE_SYSTEM_TEST_RESULTS_DIRECTORY" => results_path,
          "COLLECT_CORE_SYSTEM_MAP" => "false",
          "SPEC_OPTS" => nil,
        },
        RbConfig.ruby,
        "-rrspec/core",
        "-e",
        "exit RSpec::Core::Runner.run(ARGV)",
        "--",
        "--options",
        File::NULL,
        "--format",
        "documentation",
        "--require",
        File.join(scripts, "test_results.rb"),
        spec_path,
      )

    expect(status).to be_success
    expect(stdout).to include("1 example, 0 failures")
    expect(stderr).to include("Core system shadow results unavailable")
  end

  it "rejects a journal that is missing one planned example" do
    example_ids = ["./#{spec_file}[1:1]", "./#{spec_file}[1:2]"]
    rows = [
      { expected_example_ids: example_ids },
      { id: example_ids.first, file: spec_file, status: "passed", pid: 123, finished_ns: 1 },
      { completed: true },
    ]
    results = File.join(@directory, "results")
    FileUtils.mkdir_p(results)
    File.write(
      File.join(results, "examples-123.jsonl"),
      rows.map { |row| JSON.generate(row) }.join("\n"),
    )

    _, stderr, status =
      Open3.capture3(
        RbConfig.ruby,
        File.join(scripts, "results.rb"),
        "prepare",
        results,
        @directory,
        chdir: @directory,
      )

    expect(status).not_to be_success
    expect(stderr).to include("Incomplete Core system test journal")
    expect(File.exist?(File.join(@directory, "active-attempts.json"))).to eq(false)
  end

  def report_with_journal(completed:, outcome: "success", recovered: false)
    entry = {
      id: example_id,
      file: spec_file,
      location: "./#{spec_file}:2",
      status: "failed",
      pid: 123,
      finished_ns: 1,
      seconds: 0.1,
    }
    examples = [entry]
    if recovered
      examples << entry.merge(id: "./#{spec_file}[1:2]", location: "./#{spec_file}:3")
      File.write(
        File.join(@directory, "flaky.json"),
        JSON.generate([{ location_rerun_argument: entry.fetch(:location) }]),
      )
    end
    rows = [{ expected_example_ids: examples.map { |example| example.fetch(:id) } }, *examples]
    rows << { completed: true } if completed
    results = File.join(@directory, "results")
    FileUtils.mkdir_p(results)
    File.write(
      File.join(results, "examples-123.jsonl"),
      rows.map { |row| JSON.generate(row) }.join("\n"),
    )
    FileUtils.mkdir_p(File.join(@directory, File.dirname(spec_file)))
    File.write(File.join(@directory, spec_file), "")
    system("git", "init", "-q", chdir: @directory, exception: true)
    system("git", "add", spec_file, chdir: @directory, exception: true)
    plan = {
      selected_files: [spec_file],
      total_files: 1,
      fewer_files: 0,
      full_suite_fallback: nil,
      map_revision: nil,
      main_drift: [],
      selector_seconds: 0.1,
    }
    File.write(File.join(@directory, "plan.json"), JSON.generate(plan))

    _, stderr, status =
      Open3.capture3(
        { "CORE_SYSTEM_TEST_OUTCOME" => outcome, "GITHUB_STEP_SUMMARY" => "summary.md" },
        RbConfig.ruby,
        File.join(scripts, "results.rb"),
        "report",
        results,
        "plan.json",
        "report.json",
        "flaky.json",
        chdir: @directory,
      )
    raise stderr unless status.success?
    JSON.parse(File.read(File.join(@directory, "report.json")))
  end

  it "retains the selection when a worker journal has no completion record" do
    report = report_with_journal(completed: false)

    expect(report.fetch("selected_files")).to eq([spec_file])
    expect(report.fetch("measurement_complete")).to eq(false)
    expect(report.fetch("contains_failed_file")).to be_nil
    expect(report.fetch("omitted_failed_files")).to be_nil
  end

  it "marks the comparison unavailable when a successful retry has no journal" do
    report = report_with_journal(completed: true)

    expect(report.fetch("full_ci_outcome")).to eq("success")
    expect(report.fetch("measurement_complete")).to eq(false)
    expect(report.fetch("contains_failed_file")).to be_nil
  end

  it "detects a recovered example in a stale journal even when the required run failed" do
    report = report_with_journal(completed: true, outcome: "failure", recovered: true)

    expect(report.fetch("full_ci_outcome")).to eq("failure")
    expect(report.fetch("measurement_complete")).to eq(false)
    expect(report.fetch("contains_failed_file")).to be_nil
  end

  it "publishes boot lines only for files loaded before every worker ran its specs" do
    FileUtils.mkdir_p(File.join(@directory, File.dirname(spec_file)))
    File.write(File.join(@directory, spec_file), "")
    system("git", "init", "-q", chdir: @directory, exception: true)
    system("git", "add", spec_file, chdir: @directory, exception: true)
    system(
      "git",
      "-c",
      "user.email=ci@ci.invalid",
      "-c",
      "user.name=Discourse CI",
      "commit",
      "-qm",
      "fixture",
      chdir: @directory,
      exception: true,
    )
    controller = "app/controllers/tags_controller.rb"
    helper = "lib/registration.rb"
    attempts = { example_id => 123, "./#{spec_file}[1:2]" => 456 }
    workers = { 123 => { controller => [1], helper => [2] }, 456 => { controller => [1, 4] } }
    artifacts = {
      "active-attempts.json" => attempts,
      "passed-specs-by-worker.json" => {
        123 => [spec_file],
        456 => [spec_file],
      },
      "recorded-workers.json" => {
        123 => true,
        456 => true,
      },
      "browser.json" => {
        observed_example_ids: attempts.keys,
        tests_by_source: {
        },
        unmapped_browser_specs: [],
        missing_asset_maps: [],
      },
    }
    workers.each do |worker, lines|
      artifacts["ruby-#{worker}.json"] = {
        boot_lines: lines,
        boot_sources: ["config/application.rb", *lines.keys],
        dependencies: {
          spec_file => [controller, helper],
        },
      }
    end
    artifacts.each { |file, object| File.write(File.join(@directory, file), JSON.generate(object)) }

    _, stderr, status =
      Open3.capture3(
        RbConfig.ruby,
        File.join(scripts, "build_map.rb"),
        ".",
        "browser.json",
        "map.json",
        chdir: @directory,
      )
    raise stderr unless status.success?

    map = JSON.parse(File.read(File.join(@directory, "map.json")))
    expect(map.fetch("boot_lines")).to eq(controller => [1, 4])
  end
end
