# frozen_string_literal: true

require "crystalball"
require "json"
require "fileutils"

strategy = Crystalball::MapGenerator::CoverageStrategy.new
strategy.after_register
described_class_strategy = Crystalball::MapGenerator::DescribedClassStrategy.new
described_class_strategy.after_register
dependencies = Hash.new { |mapping, spec| mapping[spec] = [] }
completed_groups = 0

RSpec.configure do |config|
  config.prepend_before(:context) do
    strategy.run_before(self.class) unless self.class.metadata[:parent_example_group]
  end

  config.append_after(:context) do
    unless self.class.metadata[:parent_example_group]
      group = Crystalball::ExampleGroupMap.new(self.class)
      strategy.run_after(group, self.class)
      self.class.descendants.each do |descendant|
        described_class_strategy.run_after(group, descendant)
      end
      spec = self.class.metadata.fetch(:rerun_file_path).delete_prefix("./")
      dependencies[spec] |= group.used_files
      completed_groups += 1
    end
  end

  config.after(:suite) do
    described_class_strategy.before_finalize
    expected_groups =
      RSpec.world.example_groups.count do |group|
        !group.metadata[:skip] &&
          group.descendants.any? { |descendant| RSpec.world.filtered_examples[descendant].any? }
      end
    shared_globs =
      if defined?(Rails) && Rails.application
        [PrettyText::CoreBundle::BUNDLE, AssetProcessor::BUNDLE].flat_map(&:dependency_globs).uniq
      else
        []
      end
    directory = ENV.fetch("RSPEC_MAPPING_DIRECTORY", "tmp/rspec-mapping")
    FileUtils.mkdir_p(directory)
    File.write(
      "#{directory}/worker-#{Process.pid}.json",
      JSON.generate(
        version: 1,
        revision: ENV.fetch("GITHUB_SHA"),
        complete: completed_groups == expected_groups && !RSpec.world.non_example_failure,
        dependencies: dependencies,
        shared_globs: shared_globs,
      ),
    )
  end
end
