# frozen_string_literal: true

require "coverage"
require "json"

root = File.realpath(Dir.pwd) + "/"
dependencies = Hash.new { |hash, spec| hash[spec] = Set.new }
boot_sources = nil
loaded_ruby_sources = Set.new
setup_lines = {}
used_files =
  lambda do |record_boot: false|
    executed =
      Coverage
        .result(stop: false, clear: true)
        .each_with_object({}) do |(path, counters), sources|
          next unless path.start_with?(root)
          lines = counters.fetch(:lines)
          next unless lines.any? { |hits| hits.to_i.positive? }

          sources[path.delete_prefix(root)] = lines
        end
    ruby_sources = executed.keys.select { |source| source.end_with?(".rb") }
    loaded_new_source = ruby_sources.any? { |source| !loaded_ruby_sources.include?(source) }
    if record_boot
      ruby_sources.each do |source|
        setup_lines[source] = Set.new if source.start_with?("app/", "lib/")
      end
    end
    if record_boot || loaded_new_source
      executed.each do |source, lines|
        if protected_lines = setup_lines[source]
          lines.each_index { |index| protected_lines.add(index + 1) if lines[index].to_i.positive? }
        end
      end
    end
    loaded_ruby_sources.merge(ruby_sources)
    executed.keys
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
        setup_lines: setup_lines.transform_values(&:to_a),
      ),
    )
  end
end
