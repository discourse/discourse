# frozen_string_literal: true

RSpec.describe TurboTests::Flaky::FailedExample do
  describe "#rerun_command" do
    it "replays dynamically assigned files without retaining previous ownership" do
      example = RSpec::Core::Example.describe.example("worker failure")
      example.execution_result.status = :failed
      example.execution_result.exception = StandardError.new("worker failure")
      command = [
        "TEST_ENV_NUMBER=2",
        "TURBO_RSPEC_FILE_CLAIMS=/tmp/test-pipes/file-claims",
        "RSPEC_SILENCE_FILTER_ANNOUNCEMENTS=1",
        "bundle exec rspec --tag ~type:multisite",
        "--require ./lib/turbo_tests/dynamic_file_assignment",
        "--order random:42167",
        "--format TurboTests::JsonRowsFormatter --out tmp/test-pipes/subprocess-2",
        "--format ParallelTests::RSpec::RuntimeLogger --out tmp/turbo_rspec_runtime.log",
        "spec/system/first_spec.rb spec/system/second_spec.rb",
      ].join(" ")
      failure =
        TurboTests::FakeExample.from_obj(
          TurboTests::JsonExample.new(example).to_json,
          process_id: 2,
          command_string: command,
        )

      result = described_class.new(failure).rerun_command

      expect(Shellwords.split(result)).to eq(
        %w[
          bundle
          exec
          rspec
          --tag
          ~type:multisite
          --order
          random:42167
          spec/system/first_spec.rb
          spec/system/second_spec.rb
        ],
      )
    end
  end
end
