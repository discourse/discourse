# frozen_string_literal: true

module Migrations
  module Conversion
    # The worker's end of the progress channel. Writes one line per call down the
    # pipe to the coordinator, which parses them (see {StepCoordinator#consume}).
    # The leading tag tells the two message kinds apart: `p` for a progress batch,
    # `r` for the worker's one result. The result line can't be split by its own
    # data: JSON forbids raw control characters in strings, so `JSON.generate`
    # escapes any newline in the result as `\n` — one physical line, whatever the
    # result contains, so it survives `gets`.
    class PipeProgressSink
      def initialize(io)
        @io = io
      end

      def report_progress(progress:, warnings:, errors:)
        @io.write("p #{progress} #{warnings} #{errors}\n")
      end

      def report_result(result)
        @io.write("r #{JSON.generate(result)}\n")
      end
    end
  end
end
