# frozen_string_literal: true

module FlakySpec
  class Retry
    # @param [RSpec::Core::Example::Procsy] rspec_example_procsy
    # @param [Integer] retry_count The number of times to retry the example when it fails.
    def self.run(rspec_example_procsy, retry_count: 1)
      new(rspec_example_procsy, retry_count:).run_with_retry
    end

    # @private
    def initialize(rspec_example_procsy, retry_count:)
      @rspec_example_procsy = rspec_example_procsy
      @rspec_example = rspec_example_procsy.example
      self.retry_count = retry_count
    end

    # @private
    def metadata
      @rspec_example.metadata[:flaky_spec] ||= {}
    end

    # @private
    def attempts
      metadata[:retry_attempts] || 0
    end

    # @private
    def increment_attempts
      metadata[:retry_attempts] ||= 0
      metadata[:retry_attempts] += 1
    end

    # @private
    def retry_count
      metadata[:retry_count]
    end

    # @private
    def retry_count=(count)
      metadata[:retry_count] = count
    end

    # @private
    def failed_examples
      metadata[:failed_examples] ||= []
    end

    # @private
    def store_failed_example(example)
      failed_examples << FailedExample.new(example).to_h
    end

    # @private
    def run_with_retry
      loop do
        # Clear the exception so that the example can be re-run.
        @rspec_example.display_exception = nil

        # HACK: Clear this first because failing assertions are somehow being treated as a Capybara synchronize timeout
        # exception?
        @rspec_example.metadata[:_capybara_timeout_exception] = nil
        @rspec_example_procsy.run

        break if @rspec_example.exception.nil?

        store_failed_example(@rspec_example)

        increment_attempts
        break if attempts > retry_count
      end

      @rspec_example
    end
  end
end
