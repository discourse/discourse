# frozen_string_literal: true

module Migrations
  module Conversion
    # The worker's end of the progress channel. Writes one line per call down the
    # pipe to the coordinator, which parses them (see
    # {StepCoordinator#consume_progress}).
    class PipeProgressSink
      def initialize(io)
        @io = io
      end

      def report_max_progress(value)
        @io.write("m #{value}\n")
      end

      def report_progress(progress:, warnings:, errors:)
        @io.write("p #{progress} #{warnings} #{errors}\n")
      end
    end
  end
end
