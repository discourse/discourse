# frozen_string_literal: true

module Migrations
  module Conversion
    # The no-fork counterpart to {PipeProgressChannel}: updates the step's progress
    # directly, in-process, instead of writing down a pipe. The parent begins the
    # progress with the total, then hands it here.
    class InlineProgressChannel
      attr_reader :result

      def initialize(progress)
        @progress = progress
      end

      def report_progress(progress:, warnings:, errors:)
        @progress.update(increment_by: progress, warning_count: warnings, error_count: errors)
      end

      # Kept for the coordinator to read back after the worker runs. Round-tripped
      # through JSON so the reducer sees the same string-keyed shape it gets from a
      # forked worker, no matter the mode.
      def report_result(result)
        @result = JSON.parse(JSON.generate(result))
      end
    end
  end
end
