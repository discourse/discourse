# frozen_string_literal: true

module Migrations
  module Conversion
    class StepExecutor
      def initialize(step, reporter:)
        @step = step
        @reporter = reporter
      end

      def execute
        step_report = @reporter.start_step(@step.class.title)
        @step.execute
      ensure
        step_report.finish
      end
    end
  end
end
