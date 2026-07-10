# frozen_string_literal: true

module Migrations
  module Conversion
    # The worker's end of the progress channel. Writes one line per call down the
    # pipe to the coordinator, which reads them back through {.parse} — both
    # directions of the line format live here, so they can't drift apart.
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

      # Parses one line the sink wrote. Returns `[:progress, increment, warnings,
      # errors]`, `[:result, object]`, or nil for an unknown tag.
      def self.parse(line)
        tag, payload = line.split(" ", 2)

        case tag
        when "p"
          increment, warnings, errors = payload.split
          [:progress, increment.to_i, warnings.to_i, errors.to_i]
        when "r"
          [:result, JSON.parse(payload)]
        end
      end
    end
  end
end
