# frozen_string_literal: true

require "crystalball"
require "json"
require "fileutils"
require_relative "rspec_file_access"

ENV.delete("COLLECT_RSPEC_MAPPING")

strategy = Crystalball::MapGenerator::CoverageStrategy.new
strategy.after_register
described_class_strategy = Crystalball::MapGenerator::DescribedClassStrategy.new
described_class_strategy.after_register
dependencies = Hash.new { |mapping, spec| mapping[spec] = [] }
spec_order = []
completed_groups = 0
expected_groups = nil
boot_lines = nil
shared_globs = nil
RspecFileAccess.enable

RSpec.configure do |config|
  config.before(:suite) do
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
            relative = path.delete_prefix("#{Dir.pwd}/")
            next unless relative.start_with?("app/", "lib/")
            lines = coverage.is_a?(Hash) ? coverage[:lines] : coverage
            result[relative] = lines.each_index.filter_map do |index|
              index + 1 if lines[index].to_i > 0
            end
          end
      strategy.run_before(self.class)
    end
  end

  config.append_after(:context) do
    unless self.class.metadata[:parent_example_group]
      group = Crystalball::ExampleGroupMap.new(self.class)
      strategy.run_after(group, self.class)
      self.class.descendants.each do |descendant|
        described_class_strategy.run_after(group, descendant)
      end
      spec = self.class.metadata.fetch(:rerun_file_path).delete_prefix("./")
      spec_order << spec
      dependencies[spec] |= group.used_files
      completed_groups += 1
    end
  end

  config.after(:suite) do
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
        version: 3,
        revision: ENV.fetch("GITHUB_SHA"),
        complete:
          completed_groups == expected_groups && !RSpec.world.non_example_failure &&
            !RspecFileAccess.failure,
        dependencies: dependencies,
        spec_order: spec_order,
        boot_lines: boot_lines || {},
        identity: ENV.fetch("TEST_ENV_NUMBER", "multisite"),
        files:
          RSpec.configuration.files_to_run.map do |path|
            path.delete_prefix("#{Dir.pwd}/").delete_prefix("./")
          end,
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
