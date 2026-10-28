# frozen_string_literal: true

require "json"
require "fileutils"
require "rspec/core"

started_cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
RSpec.configure do |configuration|
  configuration.after(:suite) do
    examples = RSpec.world.all_examples.select { |example| example.execution_result.status }
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
        "outcomes" => outcomes,
        "cpu_seconds" => Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - started_cpu,
      ),
    )
  end
end
