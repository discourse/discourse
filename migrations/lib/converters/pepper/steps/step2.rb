# frozen_string_literal: true

module Migrations::Converters::Pepper
  class Step2 < Migrations::Converters::ProgressStep
    def items
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end

    def process_item(item, stats)
      sleep(0.5)
    end
  end
end
