module FlakySpec
  Failure = Struct.new(:message_lines)

  class Listener
    def initialize
      @failures = []
    end

    def seed(notification)
      @seed = notification.seed
    end

    def example_passed(notification)
    end

    def example_failed(notification)
      attempts = notification.example.respond_to?(:attempts) ? notification.example.attempts : 1

      return if attempts == 1

      @failures << Failure.new(message_lines: notification.message_lines)
    end

    def stop(notification)
      # Post consolidated failures to dev.
      # Should I build a custom plugin for this?
      # Can I do it completely via the API
      # What about turbo rspec?
    end
  end
end
