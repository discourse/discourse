# frozen_string_literal: true

module Migrations
  module Conversion
    class SerialJob
      def initialize(processor)
        @processor = processor
        @tracker = processor.tracker
      end

      def setup
        SetupGuard.run(@processor)
      end

      def run(item)
        @tracker.reset_stats!

        begin
          @processor.process(item)
        rescue StandardError => e
          @tracker.log_error("Failed to process item", exception: e, details: item)
        end

        @tracker.stats
      end

      def cleanup
      end
    end
  end
end
