# frozen_string_literal: true

module Migrations::Converters::Base
  class ParallelJob
    def initialize(step)
      @step = step
      @stats = ProgressStats.new

      @offline_connection = ::Migrations::Database::OfflineConnection.new

      ::Migrations::ForkManager.after_fork_child do
        ::Migrations::Database::IntermediateDB.setup(@offline_connection)
      end
    end

    def run(item)
      @stats.reset!
      @offline_connection.clear!

      begin
        @step.process_item(item, @stats)
      rescue StandardError => e
        @stats.log_error("Failed to process item", exception: e, details: item)
      end

      [@offline_connection.parametrized_insert_statements, @stats]
    end

    def cleanup
    end
  end
end
