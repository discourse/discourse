# frozen_string_literal: true

RSpec.describe FlakySpec::Listener do
  describe "#stop" do
    it "does not write any output file to disk when there are no flaky examples" do
      FlakySpec::Listener.new.stop(nil)

      expect(File.exist?(FlakySpec::Listener::OUTPUT_PATH)).to eq(false)
    end

    it "correctly writes an output file to disk when there are flaky examples" do
      listener = FlakySpec::Listener.new
      listener.seed(RSpec::Core::Notifications::SeedNotification.new(1234))

      normal_example = RSpec::Core::ExampleGroup.describe.example

      flaky_example = RSpec::Core::ExampleGroup.describe.example

      flaky_example.metadata[:flaky_spec] = {
        retry_attempts: 2,
        failed_examples: [
          {
            message_lines: "message lines 1",
            description: "description 1",
            backtrace: "backtrace 1",
            failure_screenshot_path: "/failures/screenshot/path/1.png",
          },
          {
            message_lines: "message lines 2",
            description: "description 2",
            backtrace: "backtrace 2",
            failure_screenshot_path: "/failures/screenshot/path/2.png",
          },
        ],
      }

      flaky_example_2 = RSpec::Core::ExampleGroup.describe.example

      flaky_example_2.metadata[:flaky_spec] = {
        retry_attempts: 1,
        failed_examples: [
          {
            message_lines: "message lines 3",
            description: "description 3",
            backtrace: "backtrace 3",
            failure_screenshot_path: "/failures/screenshot/path/3.png",
          },
        ],
      }

      [normal_example, flaky_example, flaky_example_2].each do |example|
        listener.example_passed(RSpec::Core::Notifications::ExampleNotification.for(example))
      end

      listener.stop(nil)

      expect(File.read(FlakySpec::Listener::OUTPUT_PATH)).to eq(<<~OUTPUT.chomp)
      {
        "seed": 1234,
        "flaky_examples": [
          {
            "uid": "e3e83a7a0501d439867edf28f3246785",
            "location_rerun_argument": "./spec/lib/flaky_spec/listener_spec.rb:17",
            "failed_examples": [
              {
                "message_lines": "message lines 1",
                "description": "description 1",
                "backtrace": "backtrace 1",
                "failure_screenshot_path": "/failures/screenshot/path/1.png"
              },
              {
                "message_lines": "message lines 2",
                "description": "description 2",
                "backtrace": "backtrace 2",
                "failure_screenshot_path": "/failures/screenshot/path/2.png"
              }
            ]
          },
          {
            "uid": "aa8c60324803ab6d24a9ee88fe823637",
            "location_rerun_argument": "./spec/lib/flaky_spec/listener_spec.rb:37",
            "failed_examples": [
              {
                "message_lines": "message lines 3",
                "description": "description 3",
                "backtrace": "backtrace 3",
                "failure_screenshot_path": "/failures/screenshot/path/3.png"
              }
            ]
          }
        ]
      }
      OUTPUT
    ensure
      File.delete(FlakySpec::Listener::OUTPUT_PATH) if File.exist?(FlakySpec::Listener::OUTPUT_PATH)
    end
  end
end
