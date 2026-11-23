# frozen_string_literal: true

require "coverage"
require "json"

root = File.realpath(Dir.pwd) + "/"
dependencies = Hash.new { |hash, spec| hash[spec] = Set.new }
boot_sources = nil
used_files =
  lambda do
    Coverage
      .result(stop: false, clear: true)
      .filter_map do |path, counters|
        if path.start_with?(root) && counters.fetch(:lines).any? { |hits| hits.to_i.positive? }
          path.delete_prefix(root)
        end
      end
  end

RSpec.configure do |config|
  config.prepend_before(:context) do
    next if self.class.metadata[:parent_example_group]
    sources = used_files.call
    boot_sources ||= sources
  end

  config.append_after(:context) do
    next if self.class.metadata[:parent_example_group]
    spec = self.class.metadata.fetch(:rerun_file_path).delete_prefix("./")
    dependencies[spec].merge(used_files.call)
  end

  config.after(:suite) do
    output = File.join(ENV.fetch("SYSTEM_COVERAGE_DIRECTORY"), "ruby-#{Process.pid}.json")
    File.write(
      output,
      JSON.generate(
        dependencies: dependencies.transform_values(&:to_a),
        boot_sources: boot_sources || [],
      ),
    )
  end
end
