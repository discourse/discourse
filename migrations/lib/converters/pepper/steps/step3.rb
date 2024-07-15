# frozen_string_literal: true

module Migrations::Converters::Pepper
  class Step3 < Migrations::Converters::ProgressStep
    def max_progress
      10
    end

    def items
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end

    def process_item(item, stats)
      sleep(1)
    end
  end
end
