# frozen_string_literal: true

module FlakySpec
  class FlakyExample
    # @param [RSpec::Core::Notifications::ExampleNotification] rspec_notification
    def initialize(rspec_notification)
      @rspec_notification = rspec_notification
      @rspec_example = rspec_notification.example
    end

    def uid
      Digest::MD5.hexdigest(
        "#{@rspec_example.id}-#{@rspec_example.full_description}-#{@rspec_example.location}",
      )
    end

    def attempts
      @rspec_example.metadata.dig(:flaky_spec, :retry_attempts) || 0
    end

    # See https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FExample:location_rerun_argument
    def location_rerun_argument
      @rspec_example.location_rerun_argument
    end

    def failed_examples
      @rspec_example.metadata[:flaky_spec][:failed_examples]
    end

    def to_h
      { uid:, location_rerun_argument:, failed_examples: }
    end
  end
end
