# frozen_string_literal: true

module Migrations::Converters::Base
  class SerialJob
    def initialize(step)
      @step = step
      @stats = ProgressStats.new
    end

    def run(item)
      @stats.reset!

      begin
        @step.process_item(item, @stats)
      rescue StandardError => e
        Migrations::Database::IntermediateDB::LogEntry.create!(
          type: "error",
          message: "Failed to process item",
          exception: e,
          details: item,
        )
        @stats.error_count += 1
      end

      @stats
    end

    def cleanup
    end
  end
end
