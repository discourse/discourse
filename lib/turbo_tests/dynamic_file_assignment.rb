# frozen_string_literal: true

require "digest/sha2"

module TurboTests
  module DynamicFileAssignment
    DIRECTORY = ENV["TURBO_RSPEC_FILE_CLAIMS"]
    WORKER = ENV["TEST_ENV_NUMBER"]
    private_constant :DIRECTORY, :WORKER

    def self.claim?(file)
      path = File.join(DIRECTORY, Digest::SHA256.hexdigest(File.expand_path(file)))
      File.open(path, File::WRONLY | File::CREAT | File::EXCL) { |owner| owner.write(WORKER) }
      puts "Dynamic file assignment [#{WORKER}]: #{file}"
      true
    rescue Errno::EEXIST
      File.read(path) == WORKER
    end

    module Ordering
      def ordered_example_groups
        files = super.group_by(&:file_path)
        positions = files.keys.each_with_index.to_h

        files
          .sort_by do |file, groups|
            [-groups.sum { |group| group.descendant_filtered_examples.size }, positions.fetch(file)]
          end
          .flat_map(&:last)
      end
    end

    module Execution
      def run(reporter = RSpec.configuration.reporter)
        if !metadata[:parent_example_group] &&
             !DynamicFileAssignment.claim?(metadata.fetch(:file_path))
          return true
        end

        super
      end
    end

    private_constant :Ordering, :Execution

    RSpec.configure do |config|
      config.define_derived_metadata do |metadata|
        next unless metadata.key?(:example_group)

        multisite = metadata[:type] == :multisite
        selected = DIRECTORY ? !multisite : multisite
        metadata[:if] = false unless selected
      end
    end

    if DIRECTORY
      RSpec::Core::World.prepend(Ordering)
      RSpec::Core::ExampleGroup.singleton_class.prepend(Execution)
    end
  end
end
