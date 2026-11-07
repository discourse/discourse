# frozen_string_literal: true
require "json"
require "fileutils"
require "rspec/core"
require_relative "test_inventory"
RSpec::Core::Runner.singleton_class.prepend(
  Module.new do
    def run(...)
      if ENV.key?("TEST_SELECTION_ORIGINAL_RUBYOPT")
        ENV["RUBYOPT"] = ENV.delete("TEST_SELECTION_ORIGINAL_RUBYOPT")
      end
      super
    end
  end,
)

if ENV["COLLECT_TEST_MAPPING"] == "1" && File.basename($PROGRAM_NAME) != "turbo_rspec"
  require_relative "rspec_mapping"
end

RSpec.configure do |config|
  root = "#{File.realpath(ENV.fetch("TEST_SELECTION_ROOT"))}/"
  inventory =
    JSON.parse(File.read(ENV.fetch("TEST_SELECTION_INVENTORY"))).to_h { |path| [path, true] }
  loaded = {}
  record_loaded =
    lambda do |path, registered: false|
      next unless path&.end_with?("_spec.rb")
      next unless registered || File.file?(path)
      absolute = File.exist?(path) ? File.realpath(path) : File.expand_path(path)
      unless registered || inventory.key?(absolute) ||
               TestInventory.test_file?(absolute.delete_prefix(root))
        next
      end
      loaded[absolute] = true
    end
  loading_traces = []
  compilation_trace =
    TracePoint.new(:script_compiled) do |event|
      instruction_sequence = event.instruction_sequence
      path = instruction_sequence.absolute_path
      next unless path&.end_with?("_spec.rb") && File.file?(path)
      absolute = File.realpath(path)
      next unless inventory.key?(absolute) || TestInventory.test_file?(absolute.delete_prefix(root))
      unless instruction_sequence.trace_points.any? { |_, type| type == :line }
        record_loaded.call(path)
        next
      end
      loading_trace = nil
      loading_trace =
        TracePoint.new(:line) do
          record_loaded.call(path)
          loading_trace.disable
        end
      loading_traces << loading_trace
      loading_trace.enable(target: instruction_sequence)
    end
  compilation_trace.enable
  config.after(:suite) do
    observed =
      config.reporter.examples.reject { |example| example.execution_result.example_skipped? }
    compilation_trace.disable
    loading_traces.each(&:disable)
    $LOADED_FEATURES.each(&record_loaded)
    RSpec
      .world
      .all_examples
      .map { |example| example.metadata.fetch(:file_path) }
      .uniq
      .each { |path| record_loaded.call(path, registered: true) }
    normalize = ->(path) do
      absolute = File.exist?(path) ? File.realpath(path) : File.expand_path(path)
      absolute.delete_prefix(root)
    end
    directory = ENV.fetch("TEST_EXECUTION_DIRECTORY")
    FileUtils.mkdir_p(directory)
    File.write(
      "#{directory}/rspec-#{Process.pid}.json",
      JSON.generate(
        revision: ENV.fetch("GITHUB_SHA"),
        identity:
          ENV.fetch("TEST_MAPPING_PROCESS_ID") { ENV.fetch("TEST_ENV_NUMBER", "multisite") },
        pid: Process.pid,
        seed: RSpec.configuration.seed,
        files: (RSpec.configuration.files_to_run + loaded.keys).map(&normalize).uniq.sort,
        executed_files:
          observed
            .map do |example|
              example.metadata.fetch(:rerun_file_path, example.metadata.fetch(:file_path))
            end
            .uniq
            .map(&normalize)
            .sort,
        examples: observed.length,
        failures: config.reporter.failed_examples.map(&:id),
        non_example_failure: RSpec.world.non_example_failure,
      ),
    )
  end
end
