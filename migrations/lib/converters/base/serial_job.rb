# frozen_string_literal: true

module Migrations
  module Converters
    module Base
      class SerialJob
        def initialize(step)
          @step = step
          @tracker = step.tracker
        end

        def run(item)
          @tracker.reset_stats!

          begin
            @step.process_item(item)
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
end
