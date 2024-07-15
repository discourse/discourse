# frozen_string_literal: true

module Migrations::Converters
  class ItemHandler
    def initialize(step, db_path = nil)
      @step = step
      @stats = ProgressStats.new
      @db_path = db_path
    end

    def after_fork
      # @step.output_db = @step.output_db.class.new(path: @db_path, journal_mode: "off")
    end

    def handle(item)
      @stats.reset!

      begin
        @step.process_item(item, @stats)
      rescue StandardError => e
        Migrations::IntermediateDb::LogEntry.create!(
          type: "error",
          message: "Failed to process item",
          exception: e,
          details: item,
        )
        @stats.error_count += 1
      end

      @stats
    end

    def close
      # @step.output_db.close
    end
  end
end
