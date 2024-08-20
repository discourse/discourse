# frozen_string_literal: true

module Migrations::Converters::Base
  class ParallelJob
    IntermediateDB = ::Migrations::Database::IntermediateDB

    def initialize(step)
      @step = step
      @stats = ProgressStats.new

      @offline_connection = ::Migrations::Database::OfflineConnection.new

      ::Migrations::ForkManager.instance.after_fork_child do
        IntermediateDB.setup(@offline_connection)
      end
    end

    def run(item)
      @stats.reset!
      @offline_connection.clear!

      begin
        @step.process_item(item, @stats)
      rescue StandardError => e
        IntermediateDB::LogEntry.create!(
          type: "error",
          message: "Failed to process item",
          exception: e,
          details: item,
        )
        @stats.error_count += 1
      end

      [@offline_connection.parametrized_insert_statements, @stats]
    end

    def cleanup
      # no-op
    end
  end
end
