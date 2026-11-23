# frozen_string_literal: true

require "coverage"
require "json"

root = File.realpath(Dir.pwd) + "/"
dependencies = Hash.new { |hash, spec| hash[spec] = Set.new }
boot_sources = nil
boot_lines = {}
used_files =
  lambda do |record_boot: false|
    Coverage
      .result(stop: false, clear: true)
      .filter_map do |path, counters|
        next unless path.start_with?(root)
        lines = counters.fetch(:lines)
        next unless lines.any? { |hits| hits.to_i.positive? }

        source = path.delete_prefix(root)
        if record_boot && source.start_with?("app/", "lib/") && source.end_with?(".rb")
          boot_lines[source] = lines.each_index.filter_map do |index|
            index + 1 if lines[index].to_i.positive?
          end
        end
        source
      end
  end

RSpec.configure do |config|
  config.prepend_before(:context) do
    next if self.class.metadata[:parent_example_group]
    sources = used_files.call(record_boot: boot_sources.nil?)
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
        boot_lines:,
      ),
    )
  end
end
