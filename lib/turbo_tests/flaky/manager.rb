# frozen_string_literal: true

module TurboTests
  module Flaky
    class Manager
      PATH = Rails.root.join("tmp/turbo_rspec_flaky_tests.json")

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
        flaky_tests =
          JSON
            .parse(File.read(PATH))
            .reject do |failed_example|
              failed_examples.any? do |example|
                failed_example["location_rerun_argument"] == example.location_rerun_argument
              end
            end

        if flaky_tests.present?
          File.write(PATH, flaky_tests.to_json)
        else
          File.delete(PATH)
        end
      end
    end
  end
end
