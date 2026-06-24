# frozen_string_literal: true

module Migrations
  module Conversion
    class StepExecutor
      def initialize(step, reporter:)
        @step = step
        @reporter = reporter
      end

      def execute
        @reporter.start_step(@step.class.title)
        @step.execute
      ensure
        @reporter.finish_step(@step.class.title)
      end
    end
  end
end
