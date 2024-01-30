# frozen_string_literal: true

module TurboTests
  module Flaky
    # This class is responsible for logging the failed examples in JSON format with the necessary debugging information
    # to debug the test failures. See `TurboTests::Flaky::FailedExample#to_h` for the debugging information that we log.
    class FailuresLoggerFormatter
      def dump_summary(notification, _timings)
        Manager.log_potential_flaky_tests(notification.failed_examples)
      end
    end
  end
end
