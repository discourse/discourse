# frozen_string_literal: true

require "crystalball"
require "json"
require "fileutils"
require "rspec/core"
require_relative "rspec_file_access"
require_relative "ruby_dependencies"

ENV.delete("COLLECT_RSPEC_MAPPING")

strategy = Crystalball::MapGenerator::CoverageStrategy.new
strategy.after_register
described_class_strategy = Crystalball::MapGenerator::DescribedClassStrategy.new
described_class_strategy.after_register
dependencies = Hash.new { |mapping, spec| mapping[spec] = [] }
root = ENV.fetch("TEST_SELECTION_ROOT", Dir.pwd)
roots = [File.expand_path(root), File.realpath(root)].uniq.map { |path| "#{path}/" }
normalize = ->(path) do
  expanded = File.expand_path(path)
  prefix = roots.find { |candidate| expanded.start_with?(candidate) }
  prefix ? expanded.delete_prefix(prefix) : expanded
end
spec_order = []
completed_groups = 0
expected_groups = nil
boot_lines = nil
shared_globs = nil
multisite_only = false
RspecFileAccess.enable(root: root)
ruby_dependencies = TestSelection::RubyDependencies.new(root: root)
ruby_dependencies.start

RSpec.configure do |config|
  config.before(:suite) do
    multisite_only = config.inclusion_filter.rules[:type].to_s == "multisite"
    expected_groups =
      RSpec.world.example_groups.count do |group|
        !group.metadata[:skip] &&
          group.descendants.any? { |descendant| RSpec.world.filtered_examples[descendant].any? }
      end
  end

  config.prepend_before(:context) do
    unless self.class.metadata[:parent_example_group]
      unless shared_globs
        shared_globs =
          (
            if defined?(Rails) && Rails.application
              [PrettyText::CoreBundle::BUNDLE, AssetProcessor::BUNDLE].flat_map(
                &:dependency_globs
              ).uniq
            else
              []
            end
          )
        RspecFileAccess.configure_shared_globs(shared_globs)
      end
      boot_lines ||=
        Coverage
          .peek_result
          .each_with_object({}) do |(path, coverage), result|
            relative = normalize.call(path)
            unless relative.end_with?(".rb") && !relative.start_with?("/", "tmp/") &&
                     !(relative.start_with?("spec/") && relative.end_with?("_spec.rb"))
              next
            end
            lines = coverage.is_a?(Hash) ? coverage[:lines] : coverage
            result[relative] = lines.each_index.filter_map do |index|
              index + 1 if lines[index].to_i > 0
            end
          end
      strategy.run_before(self.class)
      ruby_dependencies.begin_test(normalize.call(self.class.metadata.fetch(:rerun_file_path)))
    end
  end

  config.append_after(:context) do
    unless self.class.metadata[:parent_example_group]
      group = Crystalball::ExampleGroupMap.new(self.class)
      strategy.run_after(group, self.class)
      self.class.descendants.each do |descendant|
        described_class_strategy.run_after(group, descendant)
      end
      spec = normalize.call(self.class.metadata.fetch(:rerun_file_path))
      spec_order << spec
      dependencies[spec] |= group.used_files.map(&normalize)
      ruby_dependencies.finish_test
      completed_groups += 1
    end
  end

  config.after(:suite) do
    ruby_dependencies.stop
    ruby_snapshot = ruby_dependencies.snapshot(compact: true)
    described_class_strategy.before_finalize
    shared_globs =
      if defined?(Rails) && Rails.application
        [PrettyText::CoreBundle::BUNDLE, AssetProcessor::BUNDLE].flat_map(&:dependency_globs).uniq
      else
        []
      end
    RspecFileAccess.configure_shared_globs(shared_globs)
    directory = ENV.fetch("RSPEC_MAPPING_DIRECTORY", "tmp/rspec-mapping")
    FileUtils.mkdir_p(directory)
    File.write(
      "#{directory}/worker-#{Process.pid}.json",
      JSON.generate(
        version: 5,
        environment: ENV["TEST_SELECTION_ENVIRONMENT"],
        revision: ENV.fetch("GITHUB_SHA"),
        complete:
          completed_groups == expected_groups && !RSpec.world.non_example_failure &&
            !RspecFileAccess.failure,
        dependencies: dependencies,
        dependency_graph: ruby_snapshot.fetch("dependency_graph"),
        tests: ruby_snapshot.fetch("tests"),
        initialization_sources: ruby_snapshot.fetch("initialization_sources"),
        uncertain_sources: ruby_snapshot.fetch("uncertain_sources"),
        observed_sources: ruby_snapshot.fetch("observed_sources"),
        initialization_lines: ruby_snapshot.fetch("initialization_lines"),
        spec_order: spec_order,
        boot_lines: boot_lines || {},
        identity:
          ENV.fetch("TEST_MAPPING_PROCESS_ID") { ENV.fetch("TEST_ENV_NUMBER", "multisite") },
        pid: Process.pid,
        multisite_only:,
        files: RSpec.configuration.files_to_run.map { |path| normalize.call(path) },
        shared_globs: shared_globs,
        shared_files: RspecFileAccess.shared_files,
        input_failure: RspecFileAccess.failure,
        completed_groups: completed_groups,
        expected_groups: expected_groups,
        non_example_failure: RSpec.world.non_example_failure,
      ),
    )
  end
end
