# frozen_string_literal: true

module TurboTests
  # An RSpec formatter used for each subprocess during parallel test execution
  class JsonRowsFormatter
    RSpec::Core::Formatters.register(
      self,
      :close,
      :example_failed,
      :example_passed,
      :example_pending,
      :message,
      :seed,
    )

    attr_reader :output

    def initialize(output)
      @output = output
    end

    def example_passed(notification)
      output_row(type: :example_passed, example: JsonExample.new(notification.example).to_json)
    end

    def example_pending(notification)
      output_row(type: :example_pending, example: JsonExample.new(notification.example).to_json)
    end

    def example_failed(notification)
      output_row(type: :example_failed, example: JsonExample.new(notification.example).to_json)
    end

    def seed(notification)
      output_row(type: :seed, seed: notification.seed)
    end

    def close(notification)
      output_row(type: :close)
    end

    def message(notification)
      output_row(type: :message, message: notification.message)
    end

    private

    def output_row(obj)
      output.puts(obj.to_json)
      output.flush
    end
  end
end
