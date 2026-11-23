# frozen_string_literal: true

require "json"

class CoreSystemTestResults
  RSpec::Core::Formatters.register(
    self,
    :start,
    :example_passed,
    :example_failed,
    :example_pending,
    :dump_summary,
  )

  def initialize(path)
    @path = path
  end

  def start(notification)
    expected = RSpec.world.example_groups.flat_map(&:descendant_filtered_examples).map(&:id)
    unless expected.size == notification.count
      raise "Core system result manifest differs from RSpec"
    end

    @output = File.open(@path, "w")
    write(expected_example_ids: expected)
  rescue StandardError => error
    output_failed(error)
  end

  def example_passed(notification)
    example = notification.example
    write(
      id: example.id,
      file: example.metadata.fetch(:rerun_file_path).delete_prefix("./"),
      status: example.execution_result.status,
      seconds: example.execution_result.run_time,
      finished_ns: Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond),
      pid: Process.pid,
    )
  rescue StandardError => error
    output_failed(error)
  end

  alias example_failed example_passed
  alias example_pending example_passed

  def dump_summary(notification)
    write(completed: notification.errors_outside_of_examples_count.zero?)
    @output&.close
  rescue StandardError => error
    output_failed(error)
  end

  private

  def write(**record)
    return unless @output
    @output.puts(JSON.generate(record))
    @output.flush
  end

  def output_failed(error)
    raise error if ENV["COLLECT_CORE_SYSTEM_MAP"] == "true"
    warn "Core system shadow results unavailable: #{error.message}"
    @output = nil
  end
end

RSpec.configure do |config|
  directory = ENV.fetch("CORE_SYSTEM_TEST_RESULTS_DIRECTORY")
  path = File.join(directory, "examples-#{Process.pid}.jsonl")
  config.add_formatter(CoreSystemTestResults.new(path))
end
