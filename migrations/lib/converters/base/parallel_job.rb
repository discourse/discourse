# frozen_string_literal: true

module Migrations::Converters::Base
  class ParallelJob
    def initialize(step)
      @step = step
      @tracker = step.tracker

      @offline_connection = ::Migrations::Database::OfflineConnection.new

      ::Migrations::ForkManager.after_fork_child do
        ::Migrations::Database::IntermediateDB.setup(@offline_connection)
      end
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
