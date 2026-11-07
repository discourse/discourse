# frozen_string_literal: true

require "coverage"
require "rspec/core"
require_relative "../../lib/rspec_test_selection"

collect = ENV["COLLECT_RSPEC_MAPPING"] == "1"
collect &&= !ENV["COVERAGE"]
Coverage.start(lines: true) if collect && !Coverage.running?
started_cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
dependencies = Hash.new { |entries, spec| entries[spec] = Set.new }
root = File.realpath(Dir.pwd)

RSpec.configure do |configuration|
  if collect
    configuration.around do |example|
      before = Coverage.peek_result
      example.run
      after = Coverage.peek_result
      spec = example.metadata[:file_path].delete_prefix("./")
      dependencies[spec] << spec
      after.each do |absolute, counters|
        next if before[absolute] == counters || !absolute.start_with?(root + "/")
        path = absolute.delete_prefix(root + "/")
        dependencies[spec] << path if path.start_with?("app/", "lib/", "spec/")
      end
    end
  end

  configuration.after(:suite) do
    examples = RSpec.world.all_examples.select { |example| example.execution_result.status }
    entries =
      examples
        .group_by { |example| example.metadata[:file_path].delete_prefix("./") }
        .to_h do |spec, group|
          [
            spec,
            {
              "passed" => group.all? { |example| example.execution_result.status == :passed },
              "inputs" => dependencies[spec].sort,
            },
          ]
        end
    outcomes =
      examples.map do |example|
        {
          "id" => example.id,
          "spec" => example.metadata[:file_path].delete_prefix("./"),
          "status" => example.execution_result.status.to_s,
          "duration_seconds" => example.execution_result.run_time,
        }
      end
    directory = ENV.fetch("RSPEC_MAPPING_OUTPUT", "tmp/rspec-mapping/raw")
    FileUtils.mkdir_p(directory)
    File.write(
      File.join(directory, "#{Process.pid}.json"),
      JSON.generate(
        "specs" => entries,
        "outcomes" => outcomes,
        "cpu_seconds" => Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - started_cpu,
      ),
    )
  end
end
