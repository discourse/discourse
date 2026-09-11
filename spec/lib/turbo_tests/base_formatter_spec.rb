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
