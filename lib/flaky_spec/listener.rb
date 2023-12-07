# frozen_string_literal: true

module FlakySpec
  class Listener
    OUTPUT_PATH = Rails.root.join("tmp/flaky_spec_report_#{Process.pid}.json")

    def initialize
      @flaky_examples = []
    end

    def seed(notification)
      @seed = notification.seed
    end

    def example_passed(notification)
      example = FlakyExample.new(notification)

      return if example.attempts == 0

      @flaky_examples << example
    end

    # @returns [String, nil] the path to the output file if there are flaky examples, otherwise nil.
    def stop(_notification)
      return if @flaky_examples.blank?

      # write to json file
      File.open(OUTPUT_PATH, "w") do |f|
        f.write(JSON.pretty_generate({ seed: @seed, flaky_examples: @flaky_examples.map(&:to_h) }))
      end
    end
  end
end
