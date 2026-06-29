# frozen_string_literal: true

module Migrations
  module Conversion
    # The no-fork counterpart to {PipeProgressSink}: drives the step's progress
    # handle directly, in-process, instead of writing down a pipe.
    class InlineProgressSink
      def initialize(step_handle)
        @step_handle = step_handle
      end

      def report_max_progress(value)
        @progress = @step_handle.begin_progress(max_progress: value)
      end

      def report_progress(progress:, warnings:, errors:)
        @progress.update(increment_by: progress, warning_count: warnings, error_count: errors)
      end
    end
  end
end
