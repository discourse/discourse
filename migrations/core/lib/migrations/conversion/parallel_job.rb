# frozen_string_literal: true

module Migrations
  module Conversion
    class ParallelJob
      class SetupError < StandardError
      end

      def initialize(processor)
        @processor = processor
        @tracker = processor.tracker

        @offline_connection = Database::OfflineConnection.new
      end

      # Runs in the worker process, before the first item is processed.
      def setup
        Database::IntermediateDB.setup(@offline_connection)
        @processor.setup

        if @offline_connection.parametrized_insert_statements.any?
          raise SetupError,
                "The processor created IntermediateDB records during `setup`. Such writes are " \
                  "discarded in parallel mode; build per-worker state in `setup` and create " \
                  "records in `process` instead."
        end
      end

      def run(item)
        @tracker.reset_stats!
        @offline_connection.clear!

        begin
          @processor.process(item)
        rescue StandardError => e
          @tracker.log_error("Failed to process item", exception: e, details: item)
        end

        [@offline_connection.parametrized_insert_statements, @tracker.stats]
      end

      def cleanup
      end
    end
  end
end
