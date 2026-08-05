# frozen_string_literal: true

RSpec.describe FlakyTestCandidate do
  describe ".call" do
    it "selects a test that exceeds both thresholds across workflow runs" do
      Dir.mktmpdir do |reports_dir|
        write_report(
          reports_dir,
          workflow_run_id: 100,
          target: "official-plugins",
          reports: [
            failure("./spec/models/topic_spec.rb:10"),
            failure("./spec/models/topic_spec.rb:11"),
          ],
        )
        write_report(
          reports_dir,
          workflow_run_id: 101,
          target: "official-plugins",
          reports: [failure("./spec/models/topic_spec.rb:12")],
        )

        result =
          described_class.call(reports_dir:, minimum_occurrences: 3, minimum_workflow_runs: 2)

        expect(result[:candidates].first).to include(
          spec_path: "spec/models/topic_spec.rb",
          description: "publishes a topic",
          occurrences: 3,
          workflow_runs: %w[100 101],
          contexts: [{ build_type: "backend", target: "official-plugins" }],
        )
      end
    end

    it "does not select a frequent failure from only one workflow run" do
      Dir.mktmpdir do |reports_dir|
        write_report(
          reports_dir,
          workflow_run_id: 100,
          reports: Array.new(3) { failure("./spec/models/topic_spec.rb:10") },
        )

        result =
          described_class.call(reports_dir:, minimum_occurrences: 3, minimum_workflow_runs: 2)

        expect(result).to eq(candidates: [])
      end
    end

    it "ignores malformed reports" do
      Dir.mktmpdir do |reports_dir|
        FileUtils.mkdir_p("#{reports_dir}/100")
        File.write("#{reports_dir}/100/report.json", "not json")

        result =
          described_class.call(reports_dir:, minimum_occurrences: 1, minimum_workflow_runs: 1)

        expect(result).to eq(candidates: [])
      end
    end

    it "orders all eligible candidates by occurrence count" do
      Dir.mktmpdir do |reports_dir|
        write_report(
          reports_dir,
          workflow_run_id: 100,
          reports: [
            failure("./spec/models/topic_spec.rb:10"),
            failure("./spec/models/user_spec.rb:20", description: "creates a user"),
            failure("./spec/models/user_spec.rb:21", description: "creates a user"),
          ],
        )

        result =
          described_class.call(reports_dir:, minimum_occurrences: 1, minimum_workflow_runs: 1)

        expect(result[:candidates].map { |candidate| candidate[:description] }).to eq(
          ["creates a user", "publishes a topic"],
        )
      end
    end
  end

  def failure(location, description: "publishes a topic")
    {
      "description" => description,
      "exception_name" => "RSpec::Expectations::ExpectationNotMetError",
      "exception_message" => "expected true, got false",
      "message_lines" => "Failure/Error: expect(published).to eq(true)",
      "backtrace" => [location],
      "location_rerun_argument" => location,
      "rerun_command" => "bin/rspec #{location}",
    }
  end

  def write_report(reports_dir, workflow_run_id:, reports:, target: "core")
    directory = "#{reports_dir}/#{workflow_run_id}"
    FileUtils.mkdir_p(directory)
    File.write(
      "#{directory}/turbo_rspec_flaky_tests-backend-#{target}-123.json",
      JSON.generate(reports),
    )
  end
end
