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
        @stats.log_error("Failed to process item", exception: e, details: item)
      end

      @stats
    end

    def cleanup
    end
  end
end
