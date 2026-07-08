# frozen_string_literal: true

module Migrations
  module Conversion
    # The no-fork counterpart to {PipeProgressSink}: updates the step's progress
    # directly, in-process, instead of writing down a pipe. The parent begins the
    # progress with the total, then hands it here.
    class InlineProgressSink
      def initialize(progress)
        @progress = progress
      end

      def report_progress(progress:, warnings:, errors:)
        @progress.update(increment_by: progress, warning_count: warnings, error_count: errors)
      end
    end
  end
end
