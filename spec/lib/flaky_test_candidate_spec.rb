# frozen_string_literal: true

RSpec.describe FlakyTestCandidate do
  describe ".call" do
    it "selects a test that exceeds both thresholds across workflow runs" do
      Dir.mktmpdir do |reports_dir|
        write_report(
          reports_dir,
          workflow_run_id: 100,
          reports: [
            failure("./spec/models/topic_spec.rb:10"),
            failure("./spec/models/topic_spec.rb:11"),
          ],
        )
        write_report(
          reports_dir,
          workflow_run_id: 101,
          reports: [failure("./spec/models/topic_spec.rb:12")],
        )

        result =
          described_class.call(reports_dir:, minimum_occurrences: 3, minimum_workflow_runs: 2)

        expect(result[:candidate]).to include(
          spec_path: "spec/models/topic_spec.rb",
          description: "publishes a topic",
          occurrences: 3,
          workflow_runs: %w[100 101],
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

        expect(result).to eq(candidate: nil)
      end
    end

    it "ignores malformed reports" do
      Dir.mktmpdir do |reports_dir|
        FileUtils.mkdir_p("#{reports_dir}/100")
        File.write("#{reports_dir}/100/report.json", "not json")

        result =
          described_class.call(reports_dir:, minimum_occurrences: 1, minimum_workflow_runs: 1)

        expect(result).to eq(candidate: nil)
      end
    end
  end

  def failure(location)
    {
      "description" => "publishes a topic",
      "exception_name" => "RSpec::Expectations::ExpectationNotMetError",
      "exception_message" => "expected true, got false",
      "message_lines" => "Failure/Error: expect(published).to eq(true)",
      "backtrace" => [location],
      "location_rerun_argument" => location,
      "rerun_command" => "bin/rspec #{location}",
    }
  end

  def write_report(reports_dir, workflow_run_id:, reports:)
    directory = "#{reports_dir}/#{workflow_run_id}"
    FileUtils.mkdir_p(directory)
    File.write("#{directory}/report.json", JSON.generate(reports))
  end
end
