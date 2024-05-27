# frozen_string_literal: true

module TurboTests
  module Flaky
    class FlakyDetectorFormatter < RSpec::Core::Formatters::BaseFormatter
      RSpec::Core::Formatters.register self, :dump_failures

      def dump_failures(notification)
        Manager.remove_example(notification.failed_examples)
      end
    end
  end
end
