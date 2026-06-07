# frozen_string_literal: true

module TurboTests
  module Flaky
    class Manager
      PATH = File.join(TURBO_TESTS_REPO_ROOT, "tmp/turbo_rspec_flaky_tests.json")

      def self.potential_flaky_tests
        JSON
          .parse(File.read(PATH))
          .map { |failed_example| failed_example["location_rerun_argument"] }
      end

      def self.remove_flaky_tests
        File.delete(PATH) if File.exist?(PATH)
      end

      # This method should only be called by a formatter registered with `TurboTests::Runner` and logs the failed examples
      # to `PATH`. See `FailedExample#to_h` for the details of each example that is logged.
      #
      # @param [Array<TurboTests::FakeExample>] failed_examples
      def self.log_potential_flaky_tests(failed_examples)
        return if failed_examples.empty?

        File.open(PATH, "w") do |file|
          file.puts(
            failed_examples.map { |failed_example| FailedExample.new(failed_example).to_h }.to_json,
          )
        end
      end

      # This method should only be called by a formatter registered with `RSpec::Core::Formatters.register` and removes
      # the given examples from the log file at `PATH` by matching the `location_rerun_argument` of each example.
      #
      # @param [Array<RSpec::Core::Example>] failed_examples
      def self.remove_example(failed_examples)
        # The parallel flaky rerun (see `TurboTests::Runner#rerun_failed_examples`)
        # has every chunk process call this concurrently, so guard the
        # read-modify-write with an exclusive file lock. We keep the file in
        # place (truncated when empty) rather than deleting it so a sibling
        # process holding the same handle never races on a vanished path.
        File.open(PATH, File::RDWR) do |file|
          file.flock(File::LOCK_EX)

          content = file.read
          flaky_tests =
            (content.empty? ? [] : JSON.parse(content)).reject do |failed_example|
              failed_examples.any? do |example|
                failed_example["location_rerun_argument"] == example.location_rerun_argument
              end
            end

          file.rewind
          file.truncate(0)
          file.write(flaky_tests.to_json) unless flaky_tests.empty?
        end
      rescue Errno::ENOENT
        # The flaky log was never written (no failures) or already consumed.
      end
    end
  end
end
