# frozen_string_literal: true

module Migrations
  module Converters
    module Base
      class ParallelJob
        def initialize(step)
          @step = step
          @tracker = step.tracker

          @offline_connection = Database::OfflineConnection.new

          ForkManager.after_fork_child { Database::IntermediateDB.setup(@offline_connection) }
        end

        def run(item)
          @tracker.reset_stats!
          @offline_connection.clear!

          begin
            @step.process_item(item)
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
end
