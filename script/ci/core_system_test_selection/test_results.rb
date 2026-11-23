# frozen_string_literal: true

require "json"

class CoreSystemTestResults
  RSpec::Core::Formatters.register(self, :example_passed, :example_failed, :example_pending)

  def initialize(output)
    @output = output
  end

  def example_passed(notification)
    example = notification.example
    @output.puts(
      JSON.generate(
        id: example.id,
        file: example.metadata.fetch(:rerun_file_path).delete_prefix("./"),
        status: example.execution_result.status,
        seconds: example.execution_result.run_time,
        finished_ns: Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond),
        pid: Process.pid,
      ),
    )
    @output.flush
  end

  alias example_failed example_passed
  alias example_pending example_passed
end

RSpec.configure do |config|
  directory = ENV.fetch("CORE_SYSTEM_TEST_RESULTS_DIRECTORY")
  config.add_formatter(CoreSystemTestResults, File.join(directory, "examples-#{Process.pid}.jsonl"))
end
