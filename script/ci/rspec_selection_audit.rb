# frozen_string_literal: true

require "json"

ENV.delete("RSPEC_SELECTION_AUDIT")

class RspecSelectionAudit
  RSpec::Core::Formatters.register self, :example_failed, :dump_summary, :close

  def initialize(_output)
    execution = JSON.parse(File.read("tmp/rspec-mapping/execution.json"))
    role = ENV.key?("TEST_ENV_NUMBER") ? "regular" : "multisite"
    @selected = execution.fetch("predicted_#{role}_specs")
    @failures = []
    @omitted_failures = []
  end

  def example_failed(notification)
    example = notification.example
    spec = example.metadata.fetch(:rerun_file_path).delete_prefix("./")
    @failures << example.id
    return if @selected.include?(spec)

    @omitted_failures << example.id
  end

  def dump_summary(notification)
    @errors = notification.errors_outside_of_examples_count
  end

  def close(_notification)
    File.write(
      "tmp/rspec-mapping/audit-worker-#{Process.pid}.json",
      JSON.generate(
        identity: ENV.fetch("TEST_ENV_NUMBER", "multisite"),
        files:
          RSpec.configuration.files_to_run.map do |path|
            path.delete_prefix("#{Dir.pwd}/").delete_prefix("./")
          end,
        complete: @errors == 0,
        failures: @failures,
        omitted_failures: @omitted_failures,
      ),
    )
  end
end

RSpec.configure { |config| config.add_formatter(RspecSelectionAudit) }
