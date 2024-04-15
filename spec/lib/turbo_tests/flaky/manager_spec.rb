# frozen_string_literal: true

RSpec.describe TurboTests::Flaky::Manager do
  fab!(:rspec_example_1) do
    RSpec::Core::Example
      .describe
      .example("rspec example 1")
      .tap do |example|
        example.execution_result.status = :failed
        example.execution_result.exception =
          StandardError
            .new(
              "some error\n\n#{TurboTests::Flaky::FailedExample::SCREENSHOT_PREFIX}/some/path/to/screenshot.png",
            )
            .tap { |exception| exception.set_backtrace(["some backtrace"]) }
      end
  end

  fab!(:rspec_example_2) do
    RSpec::Core::Example
      .describe
      .example("rspec example 2")
      .tap do |example|
        example.execution_result.status = :failed
        example.execution_result.exception =
          StandardError
            .new("some error")
            .tap { |exception| exception.set_backtrace(["some backtrace"]) }
      end
  end

  fab!(:fake_example_1) do
    TurboTests::FakeExample.from_obj(
      TurboTests::JsonExample.new(rspec_example_1).to_json,
      process_id: 1,
      command_string: "some command string",
    )
  end

  fab!(:fake_example_2) do
    TurboTests::FakeExample.from_obj(
      TurboTests::JsonExample.new(rspec_example_2).to_json,
      process_id: 2,
      command_string: "some other command string",
    )
  end

  def with_fake_path
    tmp_file = Tempfile.new

    stub_const(TurboTests::Flaky::Manager, "PATH", tmp_file.path) { yield }
  ensure
    tmp_file.delete
  end

  describe ".potential_flaky_tests" do
    it "should return the failed examples' `location_rerun_argument`" do
      with_fake_path do
        TurboTests::Flaky::Manager.log_potential_flaky_tests([fake_example_1, fake_example_2])

        expect(TurboTests::Flaky::Manager.potential_flaky_tests).to eq(
          %w[
            ./spec/lib/turbo_tests/flaky/manager_spec.rb:7
            ./spec/lib/turbo_tests/flaky/manager_spec.rb:22
          ],
        )
      end
    end
  end

  describe ".log_potential_flaky_tests" do
    it "should log the failed examples correctly" do
      with_fake_path do
        TurboTests::Flaky::Manager.log_potential_flaky_tests([fake_example_1, fake_example_2])

        expect(JSON.parse(File.read(TurboTests::Flaky::Manager::PATH))).to eq(
          [
            {
              "message_lines" =>
                "Failure/Error: Unable to infer file and line number from backtrace\n\nStandardError:\n  some error\n\n  [Screenshot Image]: /some/path/to/screenshot.png",
              "description" => "rspec example 1",
              "exception_message" =>
                "some error\n\n[Screenshot Image]: /some/path/to/screenshot.png",
              "exception_name" => "StandardError",
              "backtrace" => ["some backtrace"],
              "failure_screenshot_path" => "/some/path/to/screenshot.png",
              "location_rerun_argument" => "./spec/lib/turbo_tests/flaky/manager_spec.rb:7",
              "rerun_command" => "some command string",
            },
            {
              "message_lines" =>
                "Failure/Error: Unable to infer file and line number from backtrace\n\nStandardError:\n  some error",
              "description" => "rspec example 2",
              "exception_message" => "some error",
              "exception_name" => "StandardError",
              "backtrace" => ["some backtrace"],
              "failure_screenshot_path" => nil,
              "location_rerun_argument" => "./spec/lib/turbo_tests/flaky/manager_spec.rb:22",
              "rerun_command" => "some other command string",
            },
          ],
        )
      end
    end
  end

  describe ".remove_example" do
    it "should remove the from the log file" do
      with_fake_path do
        TurboTests::Flaky::Manager.log_potential_flaky_tests([fake_example_1, fake_example_2])
        TurboTests::Flaky::Manager.remove_example([rspec_example_1])

        parsed_json = JSON.parse(File.read(TurboTests::Flaky::Manager::PATH))

        expect(parsed_json.size).to eq(1)
        expect(parsed_json.first["description"]).to eq("rspec example 2")
      end
    end

    it "should delete the log file if there are no more examples" do
      with_fake_path do
        TurboTests::Flaky::Manager.log_potential_flaky_tests([fake_example_1, fake_example_2])
        TurboTests::Flaky::Manager.remove_example([rspec_example_1, rspec_example_2])

        expect(File.exist?(TurboTests::Flaky::Manager::PATH)).to eq(false)
      end
    end
  end
end
