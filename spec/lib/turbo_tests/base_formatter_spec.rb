# frozen_string_literal: true

RSpec.describe TurboTests::BaseFormatter do
  describe "#dump_summary" do
    let(:output) { StringIO.new }
    let(:formatter) { described_class.new(output) }
    let(:examples) do
      [
        instance_double(
          RSpec::Core::Example,
          metadata: {
            rerun_file_path: Rails.root.join("spec/system/example_spec.rb").to_s,
            js_deprecations: {
              "example.deprecation" => 2,
            },
          },
        ),
        instance_double(
          RSpec::Core::Example,
          metadata: {
            rerun_file_path: Rails.root.join("plugins/example/spec/system/example_spec.rb").to_s,
            js_deprecations: {
              "example.deprecation" => 1,
            },
          },
        ),
      ]
    end
    let(:notification) do
      instance_double(
        RSpec::Core::Notifications::SummaryNotification,
        examples:,
        fully_formatted: "RSpec summary",
      )
    end

    it "prints the detailed summary when report generation succeeds" do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return(["Detailed summary", "", status])

      formatter.dump_summary(notification, nil)

      expect(output.string).to eq("\nDetailed summary\nRSpec summary\n")
    end

    it "keeps the test filename and line together for shared examples and fallback locations" do
      status = instance_double(Process::Status, success?: true)
      payload = nil
      allow(Open3).to receive(:capture3) do |*args, stdin_data:|
        payload = JSON.parse(stdin_data)
        ["Detailed summary", "", status]
      end

      [
        ["./spec/system/topics_spec.rb:75", "./spec/system/topics_spec.rb", 75],
        [nil, "./spec/support/shared_examples.rb", 40],
      ].each do |rerun_location, expected_file, expected_line|
        example =
          instance_double(
            RSpec::Core::Example,
            full_description: "Topics shared example",
            location: "./spec/support/shared_examples.rb:40",
            location_rerun_argument: rerun_location,
            metadata: {
              rerun_file_path: Rails.root.join("spec/system/topics_spec.rb").to_s,
              js_deprecations: {
                "example.deprecation" => 1,
              },
              js_deprecation_details: [{ "id" => "example.deprecation", "stack" => "stack" }],
            },
          )
        allow(notification).to receive(:examples).and_return([example])

        formatter.dump_summary(notification, nil)

        expect(payload.fetch("entries").sole.fetch("test")).to include(
          "file" => expected_file,
          "declarationLine" => expected_line,
        )
      end
    end

    it "prints the exit status, error and totals when report generation fails" do
      status = instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1)
      allow(Open3).to receive(:capture3).and_return(["", "Report command failed", status])

      formatter.dump_summary(notification, nil)

      expect(output.string).to include(
        "Failed to build detailed report (exit status 1).",
        "Report command failed",
        "| example.deprecation | 3 |",
        "| core | example.deprecation | 2 |",
        "| example | example.deprecation | 1 |",
        "RSpec summary",
      )
    end

    it "prints the launch error and totals when the report command cannot start" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT, "node")

      formatter.dump_summary(notification, nil)

      expect(output.string).to include(
        "Failed to build detailed report:",
        "node",
        "| example.deprecation | 3 |",
        "| core | example.deprecation | 2 |",
        "| example | example.deprecation | 1 |",
        "RSpec summary",
      )
    end
  end
end
