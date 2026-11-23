# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "Core system test results" do
  let(:scripts) { File.expand_path("../../script/ci/core_system_test_selection", __dir__) }
  let(:spec_file) { "spec/system/sidebar_spec.rb" }

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
end
